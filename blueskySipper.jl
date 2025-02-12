using HTTP
using JSON
using SQLite
using DBInterface
using Dates

const DB_PATH = "bluesky_archive.sqlite"
const SERVER_URL = "wss://jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post&wantedCollections=app.bsky.feed.like"

# Function to get keyword filters (modifiable dynamically)
function get_keywords()
    return ["protest", "rally", "riot", "protesters"]
end

# Initialize SQLite database
function init_db()
    println("🔄 Initializing database at: $DB_PATH")
    db = SQLite.DB(DB_PATH)
    DBInterface.execute(db, """
        CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            received_at TEXT NOT NULL,
            time_us INTEGER,
            event_type TEXT,
            text TEXT,
            created_at TEXT,
            collection TEXT,
            operation TEXT,
            rev TEXT,
            did TEXT,
            rkey TEXT,
            cid TEXT,
            subject_cid TEXT,
            subject_uri TEXT,
            embed_type TEXT,
            image_ref TEXT,
            image_mime TEXT,
            image_size INTEGER,
            aspect_ratio_width INTEGER,
            aspect_ratio_height INTEGER,
            raw_json TEXT NOT NULL
        )
    """)
    println("✅ Database initialized successfully")
    return db
end

# Function to check if text contains any keyword
function contains_keyword(text::String, keywords::Vector{String})
    return any(kw -> occursin(kw, lowercase(text)), lowercase.(keywords))
end

# Save raw message data to SQLite
function save_message(db, event_type, raw_json)
    received_at = string(Dates.now())  # Store timestamp

    # Parse JSON
    event = try
        JSON.parse(raw_json)
    catch e
        println("\n❌ JSON Parsing Error:", e)
        return false
    end

    # Extract fields safely
    did = get(event, "did", nothing)
    time_us = get(event, "time_us", nothing)

    commit = get(event, "commit", Dict())
    collection = get(commit, "collection", nothing)
    operation = get(commit, "operation", nothing)
    rev = get(commit, "rev", nothing)
    rkey = get(commit, "rkey", nothing)
    cid = get(commit, "cid", nothing)

    # Extract record details safely
    record = get(commit, "record", Dict())
    created_at = get(record, "createdAt", nothing)
    text = get(record, "text", nothing)

    # Validate text field against keyword list
    keywords = get_keywords()
    if text === nothing || (!isempty(keywords) && !contains_keyword(text, keywords))
        println("⚠️ Skipping message: No valid text or does not contain required keywords.")
        return false
    end

    # Insert into database
    try
        DBInterface.execute(db, """
            INSERT INTO messages (
                received_at, time_us, event_type, collection, operation, rev, did, 
                rkey, cid, created_at, subject_cid, subject_uri, text, embed_type, 
                image_ref, image_mime, image_size, aspect_ratio_width, aspect_ratio_height, raw_json
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (received_at, time_us, event_type, collection, operation, rev, did, rkey, cid, created_at, 
              nothing, nothing, text, nothing, nothing, nothing, nothing, 
              nothing, nothing, raw_json))

        println("💾 **Saved event:** $event_type, Collection: $collection, Text: $(text !== nothing ? (length(text) > 50 ? text[1:50] * "..." : text) : "N/A")")
        return true
    catch e
        println("\n❌ Database Error while saving message:", e)
        return false
    end
end

# WebSocket connection using HTTP.jl
function stream_firehose()
    db = init_db()
    println("\n🌍 Connecting to Jetstream: ", SERVER_URL)

    try
        HTTP.WebSockets.open(SERVER_URL) do ws
            println("✅ Connected to Jetstream firehose... (Waiting for messages...)")

            last_message_time = time()  # Track time since last message
            
            try
                while true
                    try
                        if HTTP.WebSockets.isclosed(ws)
                            println("\n🔄 WebSocket connection closed. Exiting loop...")
                            break
                        end
                        
                        data = HTTP.WebSockets.receive(ws)
                        if isempty(data)
                            sleep(0.1)
                            continue
                        end
                        
                        msg = String(data)
                        println("\n📩 **Received message! Raw Data:**\n", msg)

                        # Parse JSON safely
                        event = try
                            JSON.parse(msg)
                        catch e
                            println("\n❌ JSON Parsing Error:", e)
                            continue
                        end

                        event_type = get(event, "kind", "unknown")

                        # Save raw JSON with event type
                        if save_message(db, event_type, msg)
                            println("💾 **Saved event type:** ", event_type)
                        else
                            println("❌ Failed to save event to database.")
                        end

                        last_message_time = time()

                    catch e
                        if isa(e, InterruptException)
                            println("\n🔴 Shutdown detected. Closing connection...")
                            break
                        else
                            println("\n❌ Unexpected error:", e)
                            if isa(e, HTTP.WebSockets.WebSocketError)
                                println("WebSocket error, closing connection...")
                                break
                            end
                        end
                    end

                    # Heartbeat check every 30 seconds
                    if time() - last_message_time > 30
                        println("💤 No messages received in the last 30 seconds. Still listening...")
                        last_message_time = time()
                    end
                end
            catch e
                println("\n❌ Critical error in WebSocket loop:", e)
            finally
                if !HTTP.WebSockets.isclosed(ws)
                    try
                        HTTP.WebSockets.close(ws)
                        println("🔒 WebSocket connection closed.")
                    catch closeError
                        println("❌ Error while closing WebSocket: ", closeError)
                    end
                end
            end
        end
    catch e
        println("\n❌ WebSocket Connection Error:", e)
    end

    println("✅ Graceful shutdown complete.")
end

# Run the stream
stream_firehose()

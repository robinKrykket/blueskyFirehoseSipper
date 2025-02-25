# Bluesky Firehose Sipper

## Overview
This script listens to the Bluesky Firehose, searching for posts containing specific keywords. When a matching post is found, it is saved in an SQLite database for future analysis. Perfect for tracking trending topics, protests, and online discussions in real-time!

![image](https://github.com/user-attachments/assets/caa51b69-ac0d-49d9-b91d-672025a402b1)

## Features
- 🔍 **Keyword Filtering** – Captures posts containing keywords like *protest, rally, riot*.
- 💾 **SQLite Storage** – Saves structured data for easy querying and analysis.
- 🌐 **WebSocket Streaming** – Connects to Bluesky’s Jetstream firehose and processes messages live.
- 🛠 **Error Handling & Logging** – Skips irrelevant messages and reports errors gracefully.

## How It Works
1. **Connects** to the Bluesky Firehose via WebSockets.
2. **Receives** raw post data.
3. **Extracts** relevant fields like timestamps, text, and user IDs.
4. **Filters** posts containing specified keywords.
5. **Stores** the filtered posts in an SQLite database.
6. **Runs continuously**, logging messages and errors as needed.

## Dependencies
- `HTTP.jl` – WebSocket communication.
- `JSON.jl` – Parsing incoming JSON data.
- `SQLite.jl` & `DBInterface.jl` – Database storage.
- `Dates.jl` – Timestamp handling.

## Key Functions
### `get_keywords()`
Returns a list of keywords to track. Modify this function to change which posts are collected.

### `init_db()`
Creates or initializes the SQLite database where posts will be stored.

### `contains_keyword(text, keywords)`
Checks if a given text contains any of the specified keywords.

### `save_message(db, event_type, raw_json)`
Parses and saves relevant event data into the SQLite database. Skips messages that don't match the keyword filter.

### `stream_firehose()`
Establishes a WebSocket connection to the Bluesky Firehose, listens for messages, and processes them in real-time.

## Running the Script
Simply execute the script in Julia:
```julia
julia bluesky_collector.jl
```
It will keep running, collecting posts, and logging activity until manually stopped.

## Future Improvements
- 🏗 **Expand Keywords** – Allow dynamic keyword input at runtime.
- 📊 **Data Visualization** – Add scripts to analyze and visualize collected data.
- 🔧 **More Robust Error Handling** – Improve resilience against WebSocket disconnects.

Happy monitoring! 🚀

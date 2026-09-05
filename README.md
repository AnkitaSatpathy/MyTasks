

# MyTasks

iOS task management application that allows users to organize tasks across a
simple workflow.

Users can create, edit, delete, move, and reorder tasks. The app is designed to keep working even when the device is offline.


## Features

- View tasks by status
- Create new tasks
- Edit task title and description
- Swipe left to Delete tasks
- Swipe right or drag the task to move tasks between To Do to In Progress and In Progress to Done 
- Reorder tasks using drag and drop
- Search tasks by title or description
- Local persistence using SwiftData
- Offline task creation, editing, moving, reordering, and deletion
- Remote synchronization using an async service interface
- Sync status indicators for pending, synced, and failed changes

## Task Data

Each task contains:

- Unique identifier
- Title
- Description
- Status
- Creation date
- Last updated date
- Display order
- Sync state

## Offline Support

Tasks are saved locally first using SwiftData.

When the app is offline, changes are stored in a local pending queue. These changes are synchronized later when the network is available again.

The app shows whether changes are waiting to sync or failed to sync in toast.

## Remote Sync

The app uses a Firebase Firestore for remote synchromization.

The remote service supports:

- Fetch tasks
- Create a task
- Update a task
- Delete a task

 A mock remote service is also available for testing sync behavior without Firebase.

## Architecture

The app separates responsibilities into:

- Models for task data
- Views for SwiftUI screens and components
- ViewModels for UI state and user actions
- Repository for local persistence
- Sync engine for remote synchronization
- Remote service abstraction for network operations

## Known Limitations

- There are no automated test targets
- conflict resolution is basic implemetation 
- some peresisnnce errors are not showing 
- UI: drag to move and reorder could be better, if I had not accomodated all 3 states in one screen
-

## Assumptions 

- Tasks only move forward (To Do → In Progress → Done)
  
## Trade-Offs

- SwiftData over CoreData 
- Chose third party Firebase over native cloudkit for sync, becuase of its simple async remote database API


## Setup

1. Open `MyTasks.xcodeproj` in Xcode.
2. Resolve Swift Package Manager dependencies.
3. Run the app on an iOS simulator or device.

## Requirements

- Xcode
- iOS simulator or device 


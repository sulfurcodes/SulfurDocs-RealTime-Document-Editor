# SulfurDocs

A cross-platform, Google Docs-style collaborative document editor, built from scratch with Flutter, Node.js, MongoDB, and Socket.IO.


![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat&logo=flutter&logoColor=white)
![Node.js](https://img.shields.io/badge/Node.js-339933?style=flat&logo=node.js&logoColor=white)
![Express](https://img.shields.io/badge/Express_5-000000?style=flat&logo=express&logoColor=white)
![Socket.IO](https://img.shields.io/badge/Socket.IO-010101?style=flat&logo=socket.io&logoColor=white)
![MongoDB](https://img.shields.io/badge/MongoDB-47A248?style=flat&logo=mongodb&logoColor=white)
![JWT](https://img.shields.io/badge/JWT-000000?style=flat&logo=jsonwebtokens&logoColor=white)
![Vercel](https://img.shields.io/badge/Vercel-000000?style=flat&logo=vercel&logoColor=white)
![Render](https://img.shields.io/badge/Render-46E3B7?style=flat&logo=render&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)


> **Live App:**
[sulfurdocs.vercel.app](https://sulfurdocs.vercel.app)


> **Preview:**

[<video src="https://raw.githubusercontent.com/sulfurcodes/SulfurDocs-RealTime-Document-Editor/main/images/clipsulfurdocs.mp4" controls width="800"></video>](https://github.com/user-attachments/assets/22b04eb9-9b0e-4e04-814d-14cee1c63d68)

![Document Editor](https://raw.githubusercontent.com/sulfurcodes/Realtime-Document-Editor/main/images/image1.png)

The project started as a way to learn what actually sits behind a collaborative editor, past the text-editing UI. It now has full authentication, per-user document storage, a rich text editor, live multi-client sync, and autosave, and it's deployed and running.

## What it does

- Sign up and log in with a hashed password and a JWT session
- Create, open, and rename documents, scoped to your own account
- Edit with a full rich text editor (Flutter Quill): headings, lists, styling, and more
- See other collaborators' edits appear live while you're both in the same document
- Get changes saved automatically in the background, no manual save button
- Use it on web, desktop, or mobile from a single Flutter codebase

## Tech stack

### Frontend

- Flutter / Dart
- Riverpod for state management
- Flutter Quill for rich text editing
- Socket.IO client
- Routemaster for routing

### Backend

- Node.js, Express 5
- MongoDB with Mongoose
- Socket.IO
- JWT for auth, bcrypt for password hashing

## How real-time editing works

Every document has its own Socket.IO room, and the socket connection itself is authenticated: the server verifies the JWT on the handshake before a client can join any room, and it re-checks that the document actually belongs to that user before letting them in.

From there, the flow is delta-based rather than sending the whole document back and forth:

1. Opening a document calls `join` with the document ID over the socket.
2. Every keystroke or formatting change fires Quill's change event, which gets sent as a `typing` event carrying just that delta.
3. The server validates the delta (size-capped, must be an array) and rebroadcasts it to everyone else currently in that document's room.
4. On the client, incoming `changes` events get applied straight onto the local Quill document, so every collaborator converges on the same content.
5. In the background, a 2-second timer sends the full current delta as a `save` event, and the server persists it to MongoDB, scoped to the document owner.

## API reference

All routes below are prefixed with the backend's base URL. Routes marked 🔒 require an `Authorization: Bearer <token>` header.

| Method | Route | Purpose |
|---|---|---|
| POST | `/signup` | Create an account |
| POST | `/signin` | Log in, returns a JWT |
| GET | `/me` 🔒 | Get the current user's profile |
| POST | `/doc/create` 🔒 | Create a new untitled document |
| GET | `/doc/me` 🔒 | List documents owned by the current user |
| GET | `/doc/:id` 🔒 | Fetch a single document |
| POST | `/doc/name` 🔒 | Rename a document |
| GET | `/health` | Health check, used by Render |

## Socket.IO events

| Event | Direction | Purpose |
|---|---|---|
| `join` | client → server | Join a document's room, after an ownership check |
| `typing` | client → server | Send a Quill delta for a live edit |
| `changes` | server → client | Broadcast someone else's delta to the room |
| `save` | client → server | Persist the current full delta to MongoDB |
| `joinError` | server → client | Reject a join (bad ID, not your document) |
| `disconnect` | client ↔ server | Clean up on connection loss |

## Project structure

```
SulfurDocs-RealTime-Document-Editor/
├── backend/
│   └── src/
│       ├── app.js                    # Express app, CORS, routes
│       ├── server.js                 # HTTP + Socket.IO entry point
│       ├── config/
│       │   └── database.js           # MongoDB connection
│       ├── middlewares/
│       │   └── authMiddleware.js     # JWT verification for REST routes
│       ├── controllers/
│       │   ├── authController.js     # signup / signin / me
│       │   └── documentController.js # document CRUD
│       ├── models/
│       │   ├── user.js
│       │   └── document.js
│       ├── routes/
│       │   ├── authRoutes.js
│       │   └── documentRoutes.js
│       └── socket/
│           └── socketServer.js       # socket auth + join/typing/save events
│
└── frontend/
    └── lib/
        ├── main.dart
        ├── router.dart
        ├── config/
        │   └── environment.dart      # reads API_URL at build time
        ├── clients/
        │   └── socket_client.dart
        ├── models/
        │   └── document_model.dart
        ├── providers/                # Riverpod providers (auth, documents, signup, user)
        ├── repositories/             # auth, document, socket, local storage
        ├── services/                 # auth_service, document_service
        ├── screens/
        │   ├── home_page.dart
        │   ├── login_screen.dart
        │   ├── singup_screen.dart
        │   ├── profilepic_screen.dart
        │   └── document_screen.dart  # the actual editor + socket wiring
        └── widgets/
            └── loader.dart
```

## Getting started

### Prerequisites

- Node.js and npm
- A MongoDB connection string (local instance or Atlas)
- Flutter SDK

### Backend

```bash
cd backend
npm install
```

Create a `.env` file in `backend/` (see `backend/.env.example`):

```
PORT=5000
MONGO_CONNECTION=your_mongodb_connection_string
JWT_SECRET=replace-with-a-long-random-secret
FRONTEND_URL=http://localhost:3000
```

```bash
npm run dev
```

### Frontend

```bash
cd frontend
flutter pub get
flutter run
```

The app reads its backend URL from a compile-time `API_URL` variable and falls back to `http://localhost:5000` if it's not set. To point at a deployed backend:

```bash
flutter run --dart-define=API_URL=https://your-backend-url
```

## Deployment

The repo is set up to deploy both halves on push to `main`:

- **Backend** runs on Render (`render.yaml`), with a `/health` check endpoint and `JWT_SECRET` auto-generated on first deploy.
- **Frontend** builds as Flutter Web and deploys to Vercel (`vercel.json`), which clones the Flutter SDK during the build step and passes `API_URL` in as a build-time define.
- A GitHub Actions workflow (`.github/workflows/deploy.yml`) builds the Flutter web app on every push and pull request to `main` as a build check.

## Current status

This is a working version of the core editor, not a finished Google Docs clone. Auth, document storage, and real-time collaborative editing are all in and deployed. Sharing documents with other users (an actual invite/permissions flow) isn't built yet, documents are currently private to the account that created them.

## Why I built it

I wanted to understand what actually sits behind a collaborative editor, past just building a text editor UI. This one covers authentication, REST APIs, database persistence, Flutter state management, and WebSocket-based sync in one codebase, and it's deployed rather than just running locally.

## License

MIT

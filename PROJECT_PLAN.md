# Kuhrate - Spaced Repetition Note App

## Project Overview

A native iOS app for taking notes and reviewing them through a custom spaced repetition system. Users capture insights from books, podcasts, videos, and other sources, then progressively curate what matters most through weekly, monthly, and yearly reviews.

## Tech Stack

- **Platform**: Native iOS (SwiftUI)
- **Data Storage**: CoreData (local-first)
- **Minimum iOS Version**: iOS 16+
- **Language**: Swift

## Core Concept

Unlike traditional spaced repetition (like Anki), Kuhrate uses a **curation-based review cycle**:

1. Users take notes freely (daily/whenever) - all notes live in "Daily"
2. Weekly review: Curate daily notes from past week → keep important ones
3. Monthly review: Review notes kept in weekly reviews → keep important ones
4. Yearly review: Review notes kept in monthly reviews → final curation
5. Notes get "promoted" to higher cycles but always remain visible in Daily

**Mental Model**: Notes don't "move" between cycles - they get promoted to additional visibility layers.

- All notes always exist in Daily (chronological creation view)
- Weekly tab shows: notes that were kept during weekly reviews
- Monthly tab shows: notes that were kept during monthly reviews
- Yearly tab shows: notes that were kept during yearly reviews (evergreen insights)

## Data Model

### Note Entity

```swift
- id: UUID
- content: String (markdown supported, first line used as display title)
- category: Category? (optional relationship to Category entity)
- tags: [String]? (optional, unlimited)
- source: String? (optional: "Atomic Habits", "https://youtube.com/watch?v=abc", etc.)
- sourceType: SourceType? (optional relationship to SourceType entity)
- createdDate: Date
- lastReviewedDate: Date?
- reviewCycle: ReviewCycle (enum: daily, weekly, monthly, yearly)
- isArchived: Bool (default: false)
```

### SourceType Entity

```swift
- id: UUID
- name: String (e.g., "Book", "Video", "Link")
- icon: String (SF Symbol name, e.g., "book.closed")
- isCustom: Bool
- sortOrder: Int
- notes: [Note] (inverse relationship)
```

**Predefined Source Types** (seeded on first app launch):
1. Link (link)
2. Book (book.closed)
3. Video (film)
4. Podcast (mic)
5. Article (newspaper)
6. Person (person)
7. Other (asterisk)

### Category Entity

```swift
- id: UUID
- name: String (e.g., "Productivity", "Health")
- color: String (hex color like "#137fec")
- isCustom: Bool (false for predefined, true for user-created)
- sortOrder: Int (for display ordering)
- notes: [Note] (inverse relationship - all notes with this category)
```

**Predefined Categories** (seeded on first app launch):

```swift
1. Productivity → #137fec (blue)
2. Relationships → #ec4899 (pink)
3. Health → #10b981 (green)
4. Finance → #f59e0b (orange)
5. Leadership → #8b5cf6 (purple)
6. Mindset → #ef4444 (red)
7. Career → #06b6d4 (cyan)
8. Communication → #84cc16 (lime)
9. Learning → #fb923c (orange)
```

**Category Rules:**

- Predefined can be edited or deleted
- Users can create custom categories (with custom name + color)
- Users can delete their custom categories
- If a custom category is deleted, associated notes become uncategorized (category = nil)
- In UI: show categories alphabetically

**Note Lifecycle Example:**

```
Day 1: Create Note A → reviewCycle = .daily (shows in Daily tab)
Week 1 Review: Keep Note A → reviewCycle = .weekly (shows in Daily + Weekly tabs)
Month 1 Review: Keep Note A → reviewCycle = .monthly (shows in Daily + Weekly + Monthly tabs)
Year 1 Review: Keep Note A → reviewCycle = .yearly (shows in all tabs - evergreen insight)
```

**Tab Filtering Logic:**

- **Daily tab**: All notes (sorted by createdDate) - Groups by Week (Timeline View)
- **Weekly tab**: Notes where `reviewCycle >= .weekly` - Groups by Month
- **Monthly tab**: Notes where `reviewCycle >= .monthly` - Groups by Year
- **Yearly tab**: Notes where `reviewCycle == .yearly`

### ReviewCycle Enum

```swift
enum ReviewCycle: Int, Comparable {
    case daily = 0
    case weekly = 1
    case monthly = 2
    case yearly = 3

    // Allows comparison: .monthly >= .weekly = true
}
```

### ReviewSession Entity

```swift
- id: UUID
- type: ReviewType (enum: weekly, monthly, yearly)
- periodIdentifier: String (e.g., "2024-W48", "2024-11", "2024")
- status: ReviewStatus (enum: notStarted, inProgress, completed)
- totalNotes: Int (total notes to review in this session)
- notesReviewed: Int (progress tracking)
- notesKept: Int (how many were kept)
- notesArchived: Int (how many were archived)
- startedDate: Date?
- completedDate: Date?
```

### ReviewAction Entity

```swift
- id: UUID
- sessionID: UUID (which ReviewSession this action belongs to)
- noteID: UUID (which Note was reviewed)
- action: ActionType (enum: kept, archived)
- actionDate: Date
```

**Purpose**: Track individual decisions during reviews. Allows answering:

- "Which notes were kept during Week 48's review?"
- "When was this note last promoted?"
- Show review history for each note

### ReviewType Enum

```swift
enum ReviewType: String {
    case weekly
    case monthly
    case yearly
}
```

### ReviewStatus Enum

```swift
enum ReviewStatus: String {
    case notStarted
    case inProgress
    case completed
}
```

### ActionType Enum

```swift
enum ActionType: String {
    case kept       // Note was promoted to next cycle
    case archived   // Note was reviewed and removed from active cycle (retained but not promoted)
    // Implicit: No action record = Skipped/Ignored (decide later)
}
```

## Screens (from designs)

### 1. Home Screen (`home/daily-reviews-screen`)

- User avatar + settings button
- Review card showing "X Notes to Review Today"
- Filter tabs: All Notes, Weekly, Monthly, Yearly
- **Timeline Dashboard View:**
  - **Daily Tab:** Grouped by Week (e.g., "Week 48, 2024").
  - Header shows Review Status for that week (Pending/Completed).
  - Button to start review for missed weeks.
- Bottom: Search bar with voice input + FAB to add note

### 2. Weekly Review Screen (`home/weekly-reviews-screen`)

- Same header as home
- Review card showing "X Notes to Review This Week"
- Filter tabs (Weekly highlighted)
- Expandable week sections showing:
  - This Week, Last Week
  - Completion status (green checkmark)
  - Notes within each week
  - Progress indicator for incomplete reviews
- Collapsible monthly sections

### 3. Monthly/Yearly Review Screen (`monthly/yearly_review_screen`)

- Full-screen flashcard style
- Progress indicator (5 of 20)
- Note title (first line of content) + full content
- Keep / Archive buttons
- Previous / Next navigation

### 4. Add Note Screen (`add_new_note_screen`)

- Modal presentation
- Header: Close (X) | "New Note" | Save (blue)
- Timestamp display
- Large text area with placeholder (no separate title field - first line becomes title)
- Image + Mic buttons (bottom right of text area) [Phase 2]
- Footer fields (all optional):
  - Source input (with link icon) - can paste URLs, book names, etc.
  - Category selector (with icon) - predefined + custom categories
  - Tags selector (with icon, shows "Add Tags") - unlimited tags

### 5. Note Details Screen (`note_details_screen`)

- Back button | Source icon + date | Share button
- Note title (first line of content, large, bold)
- Note content (full markdown content, readable spacing)
- Category badge (colored pill with category name)
- Source card (rousnded box, if source exists)
- Tags (colored pills, if tags exist)
- Bottom action bar:
  - Edit (blue)
  - Delete (red)

## Review Logic Algorithm

### Weekly Review Trigger

**When**: Once per week (configurable day, default: Sunday)
**What to review**: All notes where `reviewCycle == .daily` AND `createdDate` is within the past 7 days

**Review Flow**:

1. Create ReviewSession (type: weekly, periodIdentifier: "2024-W48", status: inProgress)
2. User swipes through notes in flashcard UI
3. For each note:
   - **Keep** → `reviewCycle = .weekly`, create ReviewAction (action: kept)
   - **Archive** → `isArchived = true`, create ReviewAction (action: archived)
   - **Skip (No Decision)** → No action recorded. Stays pending.
4. When session complete → update ReviewSession (status: completed, completedDate: now)

### Monthly Review Trigger

**When**: Once per month (configurable date, default: 1st of month)
**What to review**: All notes where `reviewCycle == .weekly` AND were promoted to weekly during this month

**How to determine "promoted this month"**:

- Query ReviewActions where `action == .kept` AND `sessionType == .weekly`
- Filter notes where the ReviewAction's session belongs to this month
- OR: Use note's `createdDate` month + check if `reviewCycle >= .weekly`

**Review Flow**:

1. Create ReviewSession (type: monthly, periodIdentifier: "2024-11")
2. User reviews notes:
   - **Keep** → `reviewCycle = .monthly`
   - **Archive** → stays `reviewCycle = .weekly` (or archived from monthly view)
3. Complete session

### Yearly Review Trigger

**When**: Once per year (configurable date, default: Jan 1)
**What to review**: All notes where `reviewCycle == .monthly` AND were promoted to monthly during this year

**Review Flow**:

1. Create ReviewSession (type: yearly, periodIdentifier: "2024")
2. User reviews notes:
   - **Keep** → `reviewCycle = .yearly` (becomes evergreen insight)
   - **Archive** → stays `reviewCycle = .monthly`
3. Complete session

**Yearly notes**: Once promoted to `.yearly`, notes remain there indefinitely as curated evergreen insights. User can manually delete if desired.

### Review Session Flow (Detailed)

```
1. User clicks "Start Review" for a period (Week 48, November 2024, etc.)

2. System checks:
   - Are there previous reviews that weren't completed?
   - If monthly/yearly: warn if lower-level reviews incomplete
   - Calculate notes eligible for this review

3. Create ReviewSession:
   - Set totalNotes count
   - Set status = inProgress
   - Save startedDate

4. Present flashcard UI:
   - Show note content (first line as title, full content below)
   - Show progress (5 of 20)
   - Show "Keep" and "Archive" buttons
   - Allow Previous/Next navigation (Skip)

5. For each action:
   - Create ReviewAction (noteID, sessionID, action, timestamp)
   - Update note.reviewCycle if kept
   - Update note.lastReviewedDate
   - Increment ReviewSession.notesReviewed counter

6. When all notes reviewed:
   - Update ReviewSession.status = completed
   - Set completedDate
   - Return to home screen (shows green checkmark on that period)
```

## Design System

### Colors

```swift
Primary: #137fec (blue)
Background Light: #ffffff / #f7f7f7
Background Dark: #101922
Gray scale: Standard iOS grays
Success: Green (for completion checkmarks)
Destructive: Red (for delete)
```

### Typography

- Font: Inter (or SF Pro as native alternative)
- Title: 32-34pt, Bold
- Section Headers: 12pt, Medium, Uppercase, Gray
- Note Title: 16pt, Medium
- Note Preview: 14pt, Regular, Gray
- Body Text: 17pt, Regular (for reading)

### Components

- Rounded cards with subtle borders
- Pill-shaped filter tabs
- Material Icons (outlined style)
- Bottom sheets for actions
- Floating action button (FAB) for add note

## MVP Features (Phase 1)

### Must Have

- [x] All 5 core screens (Drafted/In Progress)
- [x] Create/Edit/Delete notes
- [x] Local CoreData storage
- [ ] Weekly/Monthly/Yearly review cycles
- [ ] Archive/Keep curation flow
- [x] Source, category, tags metadata
- [ ] Search functionality
- [ ] Markdown support in notes (bold, italic, lists)

### Nice to Have (Phase 2)

- [ ] iCloud sync via CloudKit
- [ ] Voice input for notes (iOS Speech framework)
- [ ] Image attachments
- [ ] Dark mode
- [ ] Widgets (show review count)
- [ ] Export notes (PDF, text)
- [ ] Custom review schedule settings
- [ ] Statistics/insights dashboard

## Project Structure

```
Kuhrate/
├── App/
│   ├── KuhrateApp.swift
│   └── ContentView.swift
├── Models/
│   ├── Note.swift
│   ├── ReviewSession.swift
│   ├── ReviewAction.swift
│   ├── ReviewCycle.swift
│   ├── ReviewType.swift
│   ├── ReviewStatus.swift
│   ├── ActionType.swift
│   └── Category.swift
├── Views/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   ├── NoteListView.swift
│   │   └── NoteRowView.swift
│   ├── Review/
│   │   ├── WeeklyReviewView.swift
│   │   ├── ReviewCardView.swift
│   │   └── ReviewSessionView.swift
│   ├── Note/
│   │   ├── AddNoteView.swift
│   │   ├── NoteDetailView.swift
│   │   └── EditNoteView.swift
│   └── Components/
│       ├── FilterTabsView.swift
│       ├── SearchBarView.swift
│       └── FABView.swift
├── ViewModels/
│   ├── NotesViewModel.swift
│   └── ReviewViewModel.swift
├── Services/
│   ├── CoreDataManager.swift
│   └── ReviewScheduler.swift
└── Resources/
    ├── Assets.xcassets
    └── Kuhrate.xcdatamodeld
```
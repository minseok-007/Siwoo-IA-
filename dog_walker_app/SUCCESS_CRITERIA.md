# PawPal Dog Walking App - Success Criteria

## What the App Can Do

### Authentication & User Management
- Users can sign up with email and password
- Users can log in and log out
- Users can choose their role: Dog Owner or Dog Walker
- Walkers can set preferences: experience level, preferred dog sizes, temperaments, energy levels, special needs support, available days, and time slots
- Users can view and edit their profile

### Dog Management (For Owners)
- Owners can add multiple dogs to their profile
- Owners can edit dog information (name, size, breed, temperament, energy level, special needs)
- Owners can delete dogs from their profile
- Owners can view all their dogs in a list

### Walk Request Management (For Owners)
- Owners can create walk requests with date, time, location, and notes
- Owners can select which dog needs walking
- Owners can view all their walk requests
- Owners can view walk request details
- Owners can cancel walk requests
- Owners can reschedule walk requests
- Owners can view walker applications for their requests
- Owners can select a walker from applications
- Owners can view scheduled walks

### Walk Application & Matching (For Walkers)
- Walkers can browse available walk requests
- Walkers can apply to walk requests
- Walkers can view their accepted walks
- Walkers can view walk request details
- Walkers can complete walks
- Available walks are automatically sorted by relevance score based on:
  - Dog size compatibility (25% weight)
  - Temperament match (20% weight)
  - Energy level alignment (15% weight)
  - Special needs support (15% weight)
  - Time compatibility (15% weight)
  - Urgency factor (10% weight)

### Optimal Schedule (For Walkers)
- Walkers can view optimal schedule suggestions using Dynamic Programming algorithm
- Algorithm finds maximum value combination of non-overlapping walks
- Walkers can filter walks by dog characteristics (size, temperament, energy level, special needs)
- Walkers can select date range for optimization
- Algorithm prevents schedule conflicts automatically
- Shows total value and number of walks in optimal schedule

### AI Recommendations (For Walkers)
- Walkers can view personalized walk request recommendations
- Uses Collaborative Filtering algorithm:
  - Finds walkers with similar preferences
  - Recommends requests that similar walkers accepted
  - Uses cosine similarity to find similar users
  - Generates recommendations using weighted average
- Shows recommendation score and reasoning

### Review System
- Users can write reviews after completed walks
- Reviews include rating (1-5 stars) and comment
- Rating system uses multiple algorithms:
  - Bayesian Average: Prevents extreme ratings for users with few reviews
  - Time-Weighted Average: Prioritizes recent reviews with exponential decay
  - Combined Rating: Balances stability and recency (40% Bayesian, 60% time-weighted)
- Users can view walker/owner profiles with ratings
- Rating trend analysis detects improvements, declines, and stability

### Real-Time Chat
- Users can send and receive messages in real-time
- Chat is automatically created when walker applies to a request
- Messages are synchronized across devices using Firestore streams
- Chat list shows last message preview
- Messages are ordered chronologically
- Chat history is preserved

### Schedule Conflict Detection
- System automatically detects time conflicts when walkers accept walks
- Uses interval overlap detection algorithm
- Prevents walkers from accepting overlapping walks
- Calculates conflict severity scores
- Shows warnings to users about conflicts

### Settings & Preferences
- Users can change app theme (light/dark mode)
- Users can change language (English/Korean)
- Users can log out
- Settings are saved and persist across sessions

### Data Management
- All data is stored in Firebase Firestore
- Real-time synchronization across devices
- Automatic authentication state management
- Data is validated before saving
- Error handling for network failures

### Algorithm Features
- **Relevance Scoring**: Multi-factor weighted algorithm for matching walkers to requests
- **Optimal Scheduling**: Dynamic Programming solution for maximum value walk selection
- **Collaborative Filtering**: User-based recommendation system using cosine similarity
- **Rating Algorithms**: Bayesian average, time-weighted average, and combined rating
- **Conflict Detection**: Interval overlap algorithm for schedule conflicts
- **Rating Trend Analysis**: Sliding window and linear regression for trend detection

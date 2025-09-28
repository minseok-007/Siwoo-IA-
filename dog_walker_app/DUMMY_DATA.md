 
# Sample Matching Data

The matching engine now considers the following walker comfort fields in addition to the original distance/price/experience inputs:

- `preferredTemperaments`: list of dog temperaments the walker can confidently handle
- `preferredEnergyLevels`: list of energy levels they enjoy walking
- `supportedSpecialNeeds`: list of special-need categories they are trained for

Below are example Firestore documents that exercise all factors. You can paste these into the Firebase console or import them via the CLI.

## `users` collection – walkers

### Advanced walker (handles energetic dogs with medication needs)

```json
{
  "id": "walker_alex",
  "email": "alex.walker@example.com",
  "fullName": "Alex Rivera",
  "phoneNumber": "+1 555 0101",
  "userType": "dogWalker",
  "experienceLevel": "expert",
  "hourlyRate": 35,
  "preferredDogSizes": ["medium", "large"],
  "preferredTemperaments": ["energetic", "friendly"],
  "preferredEnergyLevels": ["high", "veryHigh"],
  "supportedSpecialNeeds": ["medication", "training"],
  "availableDays": [1,2,3,4,5],
  "preferredTimeSlots": ["morning", "afternoon"],
  "maxDistance": 12,
  "rating": 4.9,
  "totalWalks": 182,
  "location": {
    "latitude": 37.776,
    "longitude": -122.414
  },
  "createdAt": "2024-01-10T12:00:00Z",
  "updatedAt": "2024-02-05T09:00:00Z"
}
```

### Beginner walker (prefers calm/low-energy dogs)

```json
{
  "id": "walker_jamie",
  "email": "jamie.walks@example.com",
  "fullName": "Jamie Lee",
  "phoneNumber": "+1 555 0202",
  "userType": "dogWalker",
  "experienceLevel": "beginner",
  "hourlyRate": 20,
  "preferredDogSizes": ["small", "medium"],
  "preferredTemperaments": ["calm", "shy"],
  "preferredEnergyLevels": ["low", "medium"],
  "supportedSpecialNeeds": ["none", "elderly"],
  "availableDays": [5,6],
  "preferredTimeSlots": ["afternoon", "evening"],
  "maxDistance": 6,
  "rating": 4.2,
  "totalWalks": 24,
  "location": {
    "latitude": 37.789,
    "longitude": -122.401
  },
  "createdAt": "2024-01-15T09:00:00Z",
  "updatedAt": "2024-02-10T11:30:00Z"
}
```

## `dogs` collection

```json
{
  "id": "dog_zeus",
  "ownerId": "owner_mina",
  "name": "Zeus",
  "breed": "Border Collie",
  "age": 4,
  "size": "large",
  "temperament": "energetic",
  "energyLevel": "veryHigh",
  "specialNeeds": ["training"],
  "weight": 23.5,
  "isNeutered": true,
  "medicalConditions": ["hip check"],
  "trainingCommands": ["sit", "stay", "come"],
  "isGoodWithOtherDogs": true,
  "isGoodWithChildren": true,
  "isGoodWithStrangers": false,
  "createdAt": "2024-01-01T08:00:00Z",
  "updatedAt": "2024-02-11T08:00:00Z"
}
```

```json
{
  "id": "dog_peanut",
  "ownerId": "owner_june",
  "name": "Peanut",
  "breed": "Cavalier King Charles Spaniel",
  "age": 2,
  "size": "small",
  "temperament": "calm",
  "energyLevel": "low",
  "specialNeeds": ["medication"],
  "weight": 7.1,
  "isNeutered": false,
  "medicalConditions": ["heart meds"],
  "trainingCommands": ["sit"],
  "isGoodWithOtherDogs": true,
  "isGoodWithChildren": true,
  "isGoodWithStrangers": true,
  "createdAt": "2023-12-20T10:00:00Z",
  "updatedAt": "2024-02-09T10:00:00Z"
}
```

## `walk_requests` collection (owner → Zeus)

```json
{
  "id": "walk_req_zeus_morning",
  "ownerId": "owner_mina",
  "dogId": "dog_zeus",
  "location": "Mission Dolores Park",
  "startTime": "2024-02-20T08:30:00Z",
  "endTime": "2024-02-20T09:15:00Z",
  "duration": 45,
  "notes": "High-energy morning run. Needs agility exercises.",
  "status": "pending",
  "budget": 60,
  "createdAt": "2024-02-12T07:00:00Z",
  "updatedAt": "2024-02-12T07:00:00Z"
}
```

Populate these documents (or similar) and re-open the **Smart Matching** screen to see the weighted scores react to the new walker preferences.

# Dog Walker App - System Diagrams

## 1. UML Class Diagram

```mermaid
classDiagram
    class UserModel {
        +String id
        +String email
        +String fullName
        +UserType userType
        +GeoPoint location
        +List~DogSize~ preferredDogSizes
        +List~DogTemperament~ preferredTemperaments
        +List~EnergyLevel~ preferredEnergyLevels
        +List~SpecialNeeds~ supportedSpecialNeeds
        +double rating
        +int totalWalks
        +fromFirestore(DocumentSnapshot) UserModel
        +toFirestore() Map
    }

    class DogModel {
        +String id
        +String name
        +String breed
        +String ownerId
        +DogSize size
        +DogTemperament temperament
        +EnergyLevel energyLevel
        +List~SpecialNeeds~ specialNeeds
        +double weight
        +bool isNeutered
        +fromFirestore(DocumentSnapshot) DogModel
        +toFirestore() Map
        +copyWith() DogModel
    }

    class WalkRequestModel {
        +String id
        +String ownerId
        +String walkerId
        +String dogId
        +DateTime startTime
        +DateTime endTime
        +String location
        +WalkRequestStatus status
        +int duration
        +fromFirestore(DocumentSnapshot) WalkRequestModel
        +toFirestore() Map
        +copyWith() WalkRequestModel
    }

    class WalkApplicationModel {
        +String id
        +String walkRequestId
        +String walkerId
        +String ownerId
        +ApplicationStatus status
        +String message
        +fromFirestore(DocumentSnapshot) WalkApplicationModel
        +toFirestore() Map
        +copyWith() WalkApplicationModel
    }

    class MessageModel {
        +String id
        +String chatId
        +String senderId
        +String text
        +DateTime timestamp
        +fromFirestore(DocumentSnapshot) MessageModel
        +toFirestore() Map
    }

    class RelevanceScoringService {
        <<static>>
        +calculateRelevanceScore() double
        +sortByRelevance() List~WalkRequestModel~
        -_calculateSizeCompatibilityScore() double
        -_calculateTemperamentCompatibilityScore() double
        -_calculateEnergyCompatibilityScore() double
        -_calculateSpecialNeedsSupportScore() double
        -_calculateTimeCompatibilityScore() double
        -_calculateUrgencyScore() double
        -_relevanceWeights Map~String,double~
    }

    class RatingAlgorithmService {
        <<static>>
        +calculateBayesianAverage() double
        +calculateTimeWeightedAverage() double
        +calculateConfidenceScore() double
        +calculateCombinedRating() double
    }

    class HomeScreen {
        -Set~String~ _readNotificationIds
        -int _notificationCount
        -int _unreadMessageCount
        -StreamSubscription _walkRequestSubscription
        -StreamSubscription _messageSubscription
        +_setupWalkRequestListener() void
        +_updateNotificationCount() Future~void~
        +_updateUnreadMessageCount() Future~void~
        +_markNotificationsAsRead() Future~void~
    }

    class ChatListScreen {
        -Map~String,int~ _unreadCounts
        -Map~String,DateTime~ _lastReadTimes
        -Map~String,StreamSubscription~ _messageSubscriptions
        +_getUnreadCount(String) Future~int~
        +_setupMessageListener(String) void
        +_calculateUnreadCountsQuick() Future~void~
    }

    class MessageService {
        +sendMessage(MessageModel) Future~void~
        +getMessages(String) Stream~List~MessageModel~~
        +getLastMessage(String) Future~MessageModel?~
        +initializeChat(String) Future~void~
    }

    UserModel "1" --> "*" DogModel : owns
    WalkRequestModel "1" --> "1" UserModel : owner
    WalkRequestModel "1" --> "0..1" UserModel : walker
    WalkRequestModel "1" --> "1" DogModel : for
    WalkApplicationModel "1" --> "1" WalkRequestModel : applies to
    WalkApplicationModel "1" --> "1" UserModel : walker
    MessageModel "1" --> "1" WalkRequestModel : chat for
    RelevanceScoringService ..> WalkRequestModel : uses
    RelevanceScoringService ..> DogModel : uses
    RelevanceScoringService ..> UserModel : uses
    HomeScreen ..> WalkRequestModel : displays
    HomeScreen ..> WalkApplicationModel : displays
    ChatListScreen ..> MessageModel : displays
    ChatListScreen ..> MessageService : uses
```

## 2. Firebase Firestore Data Model Diagram

```mermaid
erDiagram
    users ||--o{ dogs : owns
    users ||--o{ walk_requests : creates
    users ||--o{ walk_applications : applies
    users ||--o{ reviews : writes
    users ||--o{ chats : participates
    walk_requests ||--o{ walk_applications : has
    walk_requests ||--o{ chats : generates
    chats ||--o{ messages : contains
    dogs ||--o{ walk_requests : involved_in

    users {
        string id PK
        string email
        string fullName
        string userType
        GeoPoint location
        array preferredDogSizes
        array preferredTemperaments
        array preferredEnergyLevels
        array supportedSpecialNeeds
        double rating
        int totalWalks
        Timestamp createdAt
        Timestamp updatedAt
    }

    dogs {
        string id PK
        string ownerId FK
        string name
        string breed
        string size
        string temperament
        string energyLevel
        array specialNeeds
        double weight
        bool isNeutered
        Timestamp createdAt
        Timestamp updatedAt
    }

    walk_requests {
        string id PK
        string ownerId FK
        string walkerId FK
        string dogId FK
        Timestamp startTime
        Timestamp endTime
        string location
        string status
        int duration
        Timestamp createdAt
        Timestamp updatedAt
    }

    walk_applications {
        string id PK
        string walkRequestId FK
        string walkerId FK
        string ownerId FK
        string status
        string message
        Timestamp createdAt
        Timestamp updatedAt
    }

    chats {
        string id PK
        string ownerId FK
        string walkerId FK
        Timestamp lastMessageAt
        Timestamp createdAt
    }

    messages {
        string id PK
        string chatId FK
        string senderId FK
        string text
        Timestamp timestamp
    }

    reviews {
        string id PK
        string walkerId FK
        string ownerId FK
        string walkRequestId FK
        int rating
        string comment
        Timestamp createdAt
    }

    users_read_notifications {
        string userId FK
        array ids
        Timestamp updatedAt
    }

    users_read_messages {
        string userId FK
        map times
        Timestamp updatedAt
    }
```

## 3. Complex Method Flow Diagrams

### 3.1. Relevance Scoring Algorithm Flow

```mermaid
flowchart TD
    Start([calculateRelevanceScore Called]) --> Init[Initialize totalScore = 0.0<br/>totalWeight = 0.0]
    Init --> SizeCalc[Calculate Size Compatibility Score]
    SizeCalc --> SizeCheck{walkerPreferences<br/>contains dogSize?}
    SizeCheck -->|Yes| SizeExact[Score = 1.0]
    SizeCheck -->|No| SizeDistance[Calculate distance in sizeOrder<br/>small, medium, large]
    SizeDistance --> SizeScore{Distance?}
    SizeScore -->|0| SizeExact
    SizeScore -->|1| SizeAdjacent[Score = 0.7]
    SizeScore -->|2| SizeFar[Score = 0.3]
    SizeExact --> SizeWeight[Add sizeScore × 0.25 to totalScore]
    SizeAdjacent --> SizeWeight
    SizeFar --> SizeWeight
    SizeWeight --> TempCalc[Calculate Temperament Compatibility]
    TempCalc --> TempCheck{walkerPreferences<br/>contains dogTemperament?}
    TempCheck -->|Yes| TempMatch[Score = 1.0]
    TempCheck -->|No| TempMismatch[Score = 0.2]
    TempMatch --> TempWeight[Add tempScore × 0.20 to totalScore]
    TempMismatch --> TempWeight
    TempWeight --> EnergyCalc[Calculate Energy Level Compatibility]
    EnergyCalc --> EnergyCheck{walkerPreferences<br/>contains dogEnergyLevel?}
    EnergyCheck -->|Yes| EnergyMatch[Score = 1.0]
    EnergyCheck -->|No| EnergyMismatch[Score = 0.2]
    EnergyMatch --> EnergyWeight[Add energyScore × 0.15 to totalScore]
    EnergyMismatch --> EnergyWeight
    EnergyWeight --> SpecialCalc[Calculate Special Needs Support]
    SpecialCalc --> SpecialCheck{walker supportedNeeds<br/>contains dog specialNeeds?}
    SpecialCheck -->|Yes| SpecialMatch[Score = 1.0]
    SpecialCheck -->|No| SpecialMismatch[Score = 0.0]
    SpecialMatch --> SpecialWeight[Add specialNeedsScore × 0.15 to totalScore]
    SpecialMismatch --> SpecialWeight
    SpecialWeight --> TimeCalc[Calculate Time Compatibility]
    TimeCalc --> TimeCheck{startTime matches<br/>walker availableDays<br/>and preferredTimeSlots?}
    TimeCheck -->|Yes| TimeMatch[Score = 1.0]
    TimeCheck -->|No| TimeMismatch[Score = 0.0]
    TimeMatch --> TimeWeight[Add timeScore × 0.15 to totalScore]
    TimeMismatch --> TimeWeight
    TimeWeight --> UrgencyCalc[Calculate Urgency Score]
    UrgencyCalc --> UrgencyDays[Calculate days until startTime]
    UrgencyDays --> UrgencyCheck{Days until walk?}
    UrgencyCheck -->|< 1 day| UrgencyHigh[Score = 1.0]
    UrgencyCheck -->|< 3 days| UrgencyMed[Score = 0.7]
    UrgencyCheck -->|>= 3 days| UrgencyLow[Score = 0.3]
    UrgencyHigh --> UrgencyWeight[Add urgencyScore × 0.10 to totalScore]
    UrgencyMed --> UrgencyWeight
    UrgencyLow --> UrgencyWeight
    UrgencyWeight --> Normalize[Calculate: totalScore / totalWeight]
    Normalize --> Clamp[Clamp result between 0.0 and 1.0]
    Clamp --> Return([Return relevanceScore])
    
    style Start fill:#90EE90
    style Return fill:#90EE90
    style SizeExact fill:#FFE4B5
    style TempMatch fill:#FFE4B5
    style EnergyMatch fill:#FFE4B5
    style SpecialMatch fill:#FFE4B5
    style TimeMatch fill:#FFE4B5
    style UrgencyHigh fill:#FFE4B5
```

### 3.2. Unread Message Count Algorithm Flow

```mermaid
flowchart TD
    Start([_getUnreadCount Called]) --> GetLastRead[Get lastReadTime from _lastReadTimes map]
    GetLastRead --> GetLastMsg[Get lastMessage from MessageService]
    GetLastMsg --> CheckLastMsg{lastMessage<br/>exists?}
    CheckLastMsg -->|No| ReturnZero1[Return 0]
    CheckLastMsg -->|Yes| CheckSender{lastMessage.senderId<br/>== currentUserId?}
    CheckSender -->|Yes| ReturnZero2[Return 0 - No unread]
    CheckSender -->|No| CheckReadTime{lastReadTime<br/>exists?}
    CheckReadTime -->|No| QueryAll[Query all messages<br/>where senderId != currentUserId<br/>limit 50]
    CheckReadTime -->|Yes| CheckAfter{lastMessage.timestamp<br/>> lastReadTime?}
    CheckAfter -->|No| ReturnZero3[Return 0 - All read]
    CheckAfter -->|Yes| QueryRecent[Query recent messages<br/>orderBy timestamp desc<br/>limit 50]
    QueryAll --> FilterLoop[Loop through messages]
    QueryRecent --> FilterLoop
    FilterLoop --> CheckSenderMsg{message.senderId<br/>== currentUserId?}
    CheckSenderMsg -->|Yes| Skip[Skip message - continue loop]
    CheckSenderMsg -->|No| CheckTimestamp{lastReadTime exists<br/>AND message.timestamp<br/>> lastReadTime?}
    CheckTimestamp -->|Yes| Increment[unreadCount++]
    CheckTimestamp -->|No| CheckOrdered{Messages ordered<br/>by timestamp desc?}
    CheckOrdered -->|Yes| BreakEarly[Break early - all remaining<br/>messages are read]
    CheckOrdered -->|No| ContinueLoop[Continue loop]
    Skip --> CheckMore{More messages?}
    ContinueLoop --> CheckMore
    Increment --> CheckMore
    BreakEarly --> ReturnCount
    CheckMore -->|Yes| FilterLoop
    CheckMore -->|No| ReturnCount[Return unreadCount]
    ReturnZero1 --> End([End])
    ReturnZero2 --> End
    ReturnZero3 --> End
    ReturnCount --> End
    
    style Start fill:#90EE90
    style End fill:#90EE90
    style ReturnZero1 fill:#FFB6C1
    style ReturnZero2 fill:#FFB6C1
    style ReturnZero3 fill:#FFB6C1
    style Increment fill:#90EE90
    style BreakEarly fill:#FFE4B5
```

### 3.3. Notification Count Update Algorithm Flow

```mermaid
flowchart TD
    Start([_updateNotificationCount Called]) --> GetAuth[Get currentUserId and user from AuthProvider]
    GetAuth --> CheckAuth{currentUserId<br/>and user exist?}
    CheckAuth -->|No| End1([End - Return])
    CheckAuth -->|Yes| InitCount[Initialize count = 0]
    InitCount --> CheckUserType{user.userType?}
    CheckUserType -->|dogOwner| OwnerFlow[Owner Flow]
    CheckUserType -->|dogWalker| WalkerFlow[Walker Flow]
    
    OwnerFlow --> QueryAccepted[Query walk_requests<br/>where ownerId == currentUserId<br/>AND status == 'accepted']
    QueryAccepted --> FilterAccepted[Filter documents where:<br/>hasWalker == true<br/>AND NOT in _readNotificationIds]
    FilterAccepted --> CountAccepted[acceptedCount = filtered.length]
    CountAccepted --> QueryPending[Query walk_applications<br/>where ownerId == currentUserId<br/>AND status == 'pending']
    QueryPending --> FilterPending[Filter documents where:<br/>NOT in _readNotificationIds]
    FilterPending --> CountPending[applicationCount = filtered.length]
    CountPending --> SumOwner[count = acceptedCount + applicationCount]
    SumOwner --> UpdateUI
    
    WalkerFlow --> QueryWalker[Query walk_applications<br/>where walkerId == currentUserId<br/>AND status == 'accepted']
    QueryWalker --> FilterWalker[Filter documents where:<br/>NOT in _readNotificationIds]
    FilterWalker --> CountWalker[count = filtered.length]
    CountWalker --> UpdateUI
    
    UpdateUI{Widget mounted?} -->|Yes| SetState[setState: _notificationCount = count]
    UpdateUI -->|No| End2([End])
    SetState --> End2
    
    style Start fill:#90EE90
    style End1 fill:#FFB6C1
    style End2 fill:#90EE90
    style OwnerFlow fill:#E6E6FA
    style WalkerFlow fill:#E6E6FA
    style FilterAccepted fill:#FFE4B5
    style FilterPending fill:#FFE4B5
    style FilterWalker fill:#FFE4B5
    style SetState fill:#90EE90
```

## 4. System Architecture Overview

```mermaid
graph TB
    subgraph "Presentation Layer"
        HomeScreen[HomeScreen]
        ChatListScreen[ChatListScreen]
        ChatScreen[ChatScreen]
        NotificationsScreen[NotificationsScreen]
    end
    
    subgraph "Service Layer"
        RelevanceScoringService[RelevanceScoringService]
        RatingAlgorithmService[RatingAlgorithmService]
        MessageService[MessageService]
        WalkRequestService[WalkRequestService]
        UserService[UserService]
    end
    
    subgraph "Data Models"
        UserModel[UserModel]
        DogModel[DogModel]
        WalkRequestModel[WalkRequestModel]
        WalkApplicationModel[WalkApplicationModel]
        MessageModel[MessageModel]
    end
    
    subgraph "Firebase Firestore"
        UsersCollection[(users)]
        DogsCollection[(dogs)]
        WalkRequestsCollection[(walk_requests)]
        WalkApplicationsCollection[(walk_applications)]
        ChatsCollection[(chats)]
        MessagesCollection[(messages)]
        ReviewsCollection[(reviews)]
    end
    
    HomeScreen --> WalkRequestService
    HomeScreen --> MessageService
    ChatListScreen --> MessageService
    ChatScreen --> MessageService
    NotificationsScreen --> WalkRequestService
    
    WalkRequestService --> WalkRequestModel
    WalkRequestService --> WalkRequestsCollection
    WalkRequestService --> WalkApplicationsCollection
    MessageService --> MessageModel
    MessageService --> ChatsCollection
    MessageService --> MessagesCollection
    UserService --> UserModel
    UserService --> UsersCollection
    
    RelevanceScoringService --> WalkRequestModel
    RelevanceScoringService --> DogModel
    RelevanceScoringService --> UserModel
    
    WalkRequestModel --> DogsCollection
    WalkRequestModel --> UsersCollection
    DogModel --> UsersCollection
    MessageModel --> ChatsCollection
```

## 5. Relevance Scoring Algorithm Flow

### 5.1. Relevance Score Calculation Flow

```mermaid
flowchart TD
    Start([calculateRelevanceScore Called]) --> Init[Initialize totalScore = 0.0<br/>totalWeight = 0.0]
    
    Init --> SizeCalc[Calculate Size Compatibility Score]
    SizeCalc --> SizeWeight[Add sizeScore × 0.25 to totalScore<br/>Add 0.25 to totalWeight]
    
    SizeWeight --> TempCalc[Calculate Temperament Compatibility Score]
    TempCalc --> TempWeight[Add temperamentScore × 0.20 to totalScore<br/>Add 0.20 to totalWeight]
    
    TempWeight --> EnergyCalc[Calculate Energy Level Compatibility Score]
    EnergyCalc --> EnergyWeight[Add energyScore × 0.15 to totalScore<br/>Add 0.15 to totalWeight]
    
    EnergyWeight --> NeedsCalc[Calculate Special Needs Support Score]
    NeedsCalc --> NeedsWeight[Add specialNeedsScore × 0.15 to totalScore<br/>Add 0.15 to totalWeight]
    
    NeedsWeight --> TimeCalc[Calculate Time Compatibility Score]
    TimeCalc --> TimeWeight[Add timeScore × 0.15 to totalScore<br/>Add 0.15 to totalWeight]
    
    TimeWeight --> UrgencyCalc[Calculate Urgency Score]
    UrgencyCalc --> UrgencyWeight[Add urgencyScore × 0.10 to totalScore<br/>Add 0.10 to totalWeight]
    
    UrgencyWeight --> Normalize[Calculate: totalScore / totalWeight]
    Normalize --> Clamp[Clamp result between 0.0 and 1.0]
    Clamp --> Return([Return relevance score])
    
    style Start fill:#e1f5ff
    style Return fill:#c8e6c9
    style SizeCalc fill:#fff9c4
    style TempCalc fill:#fff9c4
    style EnergyCalc fill:#fff9c4
    style NeedsCalc fill:#fff9c4
    style TimeCalc fill:#fff9c4
    style UrgencyCalc fill:#fff9c4
```

### 5.2. Size Compatibility Score Calculation

```mermaid
flowchart TD
    Start([_calculateSizeCompatibilityScore]) --> CheckEmpty{walkerPreferences<br/>isEmpty?}
    CheckEmpty -->|Yes| ReturnNeutral[Return 0.5<br/>Neutral score]
    CheckEmpty -->|No| CheckExact{walkerPreferences<br/>contains dogSize?}
    
    CheckExact -->|Yes| ReturnPerfect[Return 1.0<br/>Perfect match]
    CheckExact -->|No| DefineOrder[Define sizeOrder:<br/>small, medium, large]
    
    DefineOrder --> GetDogIndex[Get dogIndex from sizeOrder]
    GetDogIndex --> InitBest[bestScore = 0.0]
    
    InitBest --> LoopStart[For each preferredSize<br/>in walkerPreferences]
    LoopStart --> GetPrefIndex[Get preferredIndex<br/>from sizeOrder]
    GetPrefIndex --> CalcDistance[Calculate distance =<br/>abs dogIndex - preferredIndex]
    
    CalcDistance --> CheckDist{distance == ?}
    CheckDist -->|0| Score1[score = 1.0<br/>Exact match]
    CheckDist -->|1| Score07[score = 0.7<br/>Adjacent size]
    CheckDist -->|2| Score03[score = 0.3<br/>Far size]
    CheckDist -->|Other| Score0[score = 0.0]
    
    Score1 --> UpdateBest{score > bestScore?}
    Score07 --> UpdateBest
    Score03 --> UpdateBest
    Score0 --> UpdateBest
    
    UpdateBest -->|Yes| SetBest[bestScore = score]
    UpdateBest -->|No| CheckMore{More<br/>preferences?}
    SetBest --> CheckMore
    
    CheckMore -->|Yes| LoopStart
    CheckMore -->|No| ReturnBest[Return bestScore]
    
    ReturnNeutral --> End([End])
    ReturnPerfect --> End
    ReturnBest --> End
    
    style Start fill:#e1f5ff
    style End fill:#c8e6c9
    style CheckExact fill:#fff9c4
    style CheckDist fill:#fff9c4
```

### 5.3. Energy Level Compatibility Score Calculation

```mermaid
flowchart TD
    Start([_calculateEnergyCompatibilityScore]) --> CheckEmpty{walkerPreferences<br/>isEmpty?}
    CheckEmpty -->|Yes| ReturnNeutral[Return 0.6<br/>Neutral baseline]
    CheckEmpty -->|No| CheckExact{walkerPreferences<br/>contains dogEnergy?}
    
    CheckExact -->|Yes| ReturnPerfect[Return 1.0<br/>Perfect match]
    CheckExact -->|No| DefineOrder[Define order:<br/>low, medium, high, veryHigh]
    
    DefineOrder --> GetDogIndex[Get dogIndex from order]
    GetDogIndex --> InitBest[bestScore = 0.2<br/>Base score for mismatch]
    
    InitBest --> LoopStart[For each pref<br/>in walkerPreferences]
    LoopStart --> GetPrefIndex[Get prefIndex from order]
    GetPrefIndex --> CalcDistance[Calculate distance =<br/>abs prefIndex - dogIndex]
    
    CalcDistance --> CheckAdjacent{distance == 1?}
    CheckAdjacent -->|Yes| UpdateBest[bestScore = max bestScore, 0.7<br/>Adjacent level]
    CheckAdjacent -->|No| KeepBest[Keep current bestScore]
    
    UpdateBest --> CheckMore{More<br/>preferences?}
    KeepBest --> CheckMore
    
    CheckMore -->|Yes| LoopStart
    CheckMore -->|No| ReturnBest[Return bestScore]
    
    ReturnNeutral --> End([End])
    ReturnPerfect --> End
    ReturnBest --> End
    
    style Start fill:#e1f5ff
    style End fill:#c8e6c9
    style CheckExact fill:#fff9c4
    style CheckAdjacent fill:#fff9c4
```

### 5.4. Time Compatibility Score Calculation

```mermaid
flowchart TD
    Start([_calculateTimeCompatibilityScore]) --> CheckEmpty{walkerAvailableDays<br/>isEmpty OR<br/>walkerTimeSlots isEmpty?}
    CheckEmpty -->|Yes| ReturnNeutral[Return 0.5<br/>Neutral score]
    
    CheckEmpty -->|No| GetWalkDay[Get walkDay =<br/>walkTime.weekday % 7]
    GetWalkDay --> CheckDay{walkerAvailableDays<br/>contains walkDay?}
    
    CheckDay -->|No| ReturnZero[Return 0.0<br/>Not available on this day]
    CheckDay -->|Yes| GetWalkHour[Get walkHour =<br/>walkTime.hour]
    
    GetWalkHour --> DetermineSlot{walkHour < 12?}
    DetermineSlot -->|Yes| SetMorning[walkTimeSlot = 'morning']
    DetermineSlot -->|No| CheckAfternoon{walkHour < 17?}
    
    CheckAfternoon -->|Yes| SetAfternoon[walkTimeSlot = 'afternoon']
    CheckAfternoon -->|No| SetEvening[walkTimeSlot = 'evening']
    
    SetMorning --> CheckSlot{walkerTimeSlots<br/>contains walkTimeSlot?}
    SetAfternoon --> CheckSlot
    SetEvening --> CheckSlot
    
    CheckSlot -->|Yes| ReturnPerfect[Return 1.0<br/>Perfect time match]
    CheckSlot -->|No| ReturnPartial[Return 0.5<br/>Available day but not preferred time]
    
    ReturnNeutral --> End([End])
    ReturnZero --> End
    ReturnPerfect --> End
    ReturnPartial --> End
    
    style Start fill:#e1f5ff
    style End fill:#c8e6c9
    style CheckDay fill:#fff9c4
    style CheckSlot fill:#fff9c4
```

### 5.5. Urgency Score Calculation

```mermaid
flowchart TD
    Start([_calculateUrgencyScore]) --> GetNow[Get now = DateTime.now]
    GetNow --> CalcHours[Calculate hoursUntilWalk =<br/>walkTime.difference now.inHours]
    
    CalcHours --> CheckPast{hoursUntilWalk < 0?}
    CheckPast -->|Yes| ReturnZero[Return 0.0<br/>Past walk]
    
    CheckPast -->|No| Check24{hoursUntilWalk <= 24?}
    Check24 -->|Yes| Calc24[Calculate score =<br/>1.0 - hoursUntilWalk / 24.0 × 0.2<br/>Range: 1.0 to 0.8]
    Calc24 --> Return24[Return calculated score]
    
    Check24 -->|No| CheckWeek{hoursUntilWalk <= 168?}
    CheckWeek -->|Yes| CalcWeek[Calculate score =<br/>0.8 - hoursUntilWalk - 24 / 144.0 × 0.2<br/>Range: 0.8 to 0.6]
    CalcWeek --> ReturnWeek[Return calculated score]
    
    CheckWeek -->|No| ReturnBase[Return 0.6<br/>Base score for > 1 week]
    
    ReturnZero --> End([End])
    Return24 --> End
    ReturnWeek --> End
    ReturnBase --> End
    
    style Start fill:#e1f5ff
    style End fill:#c8e6c9
    style CheckPast fill:#fff9c4
    style Check24 fill:#fff9c4
    style CheckWeek fill:#fff9c4
```

### 5.6. Sort By Relevance Flow

```mermaid
flowchart TD
    Start([sortByRelevance Called]) --> Init[Initialize scoredRequests = []]
    
    Init --> LoopStart[For each request<br/>in requests]
    LoopStart --> GetDog[Get dog from dogs map<br/>using request.dogId]
    
    GetDog --> CheckDog{dog == null?}
    CheckDog -->|Yes| Skip[Skip this request<br/>Continue loop]
    CheckDog -->|No| CalcScore[Calculate relevanceScore =<br/>calculateRelevanceScore<br/>walkRequest, dog, walker]
    
    CalcScore --> AddToScored[Add request, score<br/>to scoredRequests]
    AddToScored --> CheckMore{More<br/>requests?}
    Skip --> CheckMore
    
    CheckMore -->|Yes| LoopStart
    CheckMore -->|No| Sort[Sort scoredRequests by score<br/>descending highest first]
    
    Sort --> Map[Map scoredRequests to<br/>List of WalkRequestModel]
    Map --> Return([Return sorted list])
    
    style Start fill:#e1f5ff
    style Return fill:#c8e6c9
    style CalcScore fill:#fff9c4
    style Sort fill:#fff9c4
```

## 6. Complex Chat Method Flow Diagrams

### 5.1. Chat List Fetching Algorithm Flow

```mermaid
flowchart TD
    Start([_fetchChats Called]) --> SetLoading[Set _loading = true]
    SetLoading --> GetUser[Get user from AuthProvider]
    GetUser --> CheckUser{user exists?}
    CheckUser -->|No| End1([End - Return])
    CheckUser -->|Yes| CheckUserType{user.userType?}
    
    CheckUserType -->|dogWalker| GetWalkerRequests[Query walk_requests<br/>where walkerId == user.id]
    CheckUserType -->|dogOwner| GetOwnerRequests[Query walk_requests<br/>where ownerId == user.id]
    
    GetWalkerRequests --> InitChats[Initialize chats = []]
    GetOwnerRequests --> InitChats
    
    InitChats --> LoopStart[Loop through walkRequests]
    LoopStart --> DetermineOther[Determine otherUserId:<br/>if walker: otherUserId = walk.ownerId<br/>if owner: otherUserId = walk.walkerId]
    
    DetermineOther --> CheckOther{otherUserId<br/>isEmpty?}
    CheckOther -->|Yes| SkipChat[Skip this chat - continue loop]
    CheckOther -->|No| GetOtherUser[Get otherUser by otherUserId]
    
    GetOtherUser --> CheckOtherUser{otherUser<br/>exists?}
    CheckOtherUser -->|No| SkipChat
    CheckOtherUser -->|Yes| GetDog[Get dog by walk.dogId]
    
    GetDog --> CreateChatId[Create chatId:<br/>'walk_{walk.id}_{ownerId}_{walkerId}']
    CreateChatId --> GetLastMsg[Get lastMessage for chatId]
    
    GetLastMsg --> CheckActive{lastMessage exists OR<br/>walk.status == accepted OR<br/>walk.status == completed?}
    CheckActive -->|No| SkipChat
    CheckActive -->|Yes| AddChat[Add to chats list:<br/>chatId, walkRequest, otherUser, dog, lastMessage]
    
    AddChat --> CheckMore{More walkRequests?}
    SkipChat --> CheckMore
    CheckMore -->|Yes| LoopStart
    CheckMore -->|No| AddExistingChats[Call _addExistingChats<br/>to find chats in messages collection]
    
    AddExistingChats --> SortChats[Sort chats by timestamp:<br/>lastMessage.timestamp OR walkRequest.startTime<br/>descending order]
    SortChats --> UpdateState[setState: _chats = chats<br/>_loading = false]
    
    UpdateState --> SetupListeners[For each chat:<br/>Setup real-time message listener]
    SetupListeners --> CalcQuick[Call _calculateUnreadCountsQuick<br/>for fast initial display]
    CalcQuick --> End2([End])
    
    style Start fill:#90EE90
    style End1 fill:#FFB6C1
    style End2 fill:#90EE90
    style GetWalkerRequests fill:#E6E6FA
    style GetOwnerRequests fill:#E6E6FA
    style AddChat fill:#90EE90
    style SetupListeners fill:#FFE4B5
    style CalcQuick fill:#FFE4B5
```

### 5.2. Real-time Message Listener Setup Flow

```mermaid
flowchart TD
    Start([_setupMessageListener Called]) --> CancelExisting{Cancel existing<br/>subscription for chatId?}
    CancelExisting -->|Yes| CancelSub[Cancel _messageSubscriptions[chatId]]
    CancelExisting -->|No| CreateListener
    CancelSub --> CreateListener[Create Firestore stream listener:<br/>chats/{chatId}/messages<br/>orderBy timestamp desc<br/>limit 1]
    
    CreateListener --> ListenStart[Start listening to snapshots]
    ListenStart --> SnapshotReceived[Snapshot received]
    SnapshotReceived --> CheckMounted{Widget mounted?}
    CheckMounted -->|No| End1([End - Return])
    CheckMounted -->|Yes| CheckDocs{snapshot.docs<br/>isNotEmpty?}
    
    CheckDocs -->|No| End2([End - No messages])
    CheckDocs -->|Yes| GetLastMsg[Get lastMessageDoc<br/>from snapshot.docs.first]
    
    GetLastMsg --> ExtractData[Extract:<br/>senderId = lastMessageData['senderId']<br/>timestamp = lastMessageData['timestamp']]
    
    ExtractData --> CheckSender{senderId !=<br/>currentUserId AND<br/>timestamp != null?}
    CheckSender -->|No| End3([End - Own message or invalid])
    CheckSender -->|Yes| GetReadTime[Get lastReadTime<br/>from _lastReadTimes[chatId]]
    
    GetReadTime --> CheckUnread{lastReadTime == null OR<br/>timestamp > lastReadTime?}
    CheckUnread -->|No| End4([End - Already read])
    CheckUnread -->|Yes| CalcUnread[Call _getUnreadCount chatId<br/>to get exact unread count]
    
    CalcUnread --> CheckMounted2{Widget still<br/>mounted?}
    CheckMounted2 -->|No| End5([End])
    CheckMounted2 -->|Yes| UpdateState[setState:<br/>_unreadCounts[chatId] = unreadCount]
    
    UpdateState --> FindIndex[Find chat index:<br/>_chats.indexWhere chatId]
    FindIndex --> UpdateChatItem{Index found?}
    UpdateChatItem -->|Yes| UpdateChat[_chats[index]['unreadCount'] = unreadCount<br/>_chats[index]['lastMessage'] = new MessageModel]
    UpdateChatItem -->|No| StoreSub
    UpdateChat --> StoreSub[Store subscription:<br/>_messageSubscriptions[chatId] = subscription]
    StoreSub --> End6([End - Listener active])
    
    style Start fill:#90EE90
    style End1 fill:#FFB6C1
    style End2 fill:#FFB6C1
    style End3 fill:#FFB6C1
    style End4 fill:#FFB6C1
    style End5 fill:#FFB6C1
    style End6 fill:#90EE90
    style CalcUnread fill:#FFE4B5
    style UpdateState fill:#90EE90
    style UpdateChat fill:#90EE90
```

### 5.3. Home Screen Unread Message Count Update Flow

```mermaid
flowchart TD
    Start([_updateUnreadMessageCount Called]) --> GetAuth[Get currentUserId and user<br/>from AuthProvider]
    GetAuth --> CheckAuth{currentUserId and<br/>user exist?}
    CheckAuth -->|No| End1([End - Return])
    CheckAuth -->|Yes| InitCount[Initialize unreadCount = 0]
    
    InitCount --> QueryAllChats[Query all chats collection<br/>from Firestore]
    QueryAllChats --> LoopChats[Loop through each chatDoc]
    
    LoopChats --> ExtractChatData[Extract:<br/>ownerId = chatData['ownerId']<br/>walkerId = chatData['walkerId']<br/>chatId = chatDoc.id]
    
    ExtractChatData --> CheckParticipant{Check if user is participant:<br/>if owner: ownerId == currentUserId<br/>if walker: walkerId == currentUserId}
    
    CheckParticipant -->|No| SkipChat[Skip this chat - continue loop]
    CheckParticipant -->|Yes| GetReadTime[Get lastReadTime<br/>from _lastReadMessageTime[chatId]]
    
    GetReadTime --> GetLastMsg[Get lastMessage<br/>from MessageService]
    GetLastMsg --> CheckLastMsg{lastMessage exists AND<br/>lastMessage.senderId != currentUserId?}
    
    CheckLastMsg -->|No| SkipChat
    CheckLastMsg -->|Yes| CheckUnread{lastReadTime == null OR<br/>lastMessage.timestamp > lastReadTime?}
    
    CheckUnread -->|No| SkipChat
    CheckUnread -->|Yes| QueryRecent[Query recent messages:<br/>chats/{chatId}/messages<br/>orderBy timestamp desc<br/>limit 50]
    
    QueryRecent --> FilterLoop[Loop through recentMessages]
    FilterLoop --> CheckSender{msgSenderId ==<br/>currentUserId?}
    
    CheckSender -->|Yes| SkipMsg[Skip message - continue loop]
    CheckSender -->|No| CheckTimestamp{lastReadTime exists AND<br/>msgTimestamp > lastReadTime?}
    
    CheckTimestamp -->|Yes| Increment[chatUnreadCount++]
    CheckTimestamp -->|No| CheckOrdered{Messages ordered<br/>by timestamp desc?}
    
    CheckOrdered -->|Yes| BreakEarly[Break early - all remaining<br/>messages are read]
    CheckOrdered -->|No| ContinueLoop[Continue loop]
    
    SkipMsg --> CheckMoreMsg{More messages?}
    ContinueLoop --> CheckMoreMsg
    Increment --> CheckMoreMsg
    BreakEarly --> AddToTotal
    CheckMoreMsg -->|Yes| FilterLoop
    CheckMoreMsg -->|No| AddToTotal[unreadCount += chatUnreadCount]
    
    AddToTotal --> CheckMoreChats{More chats?}
    SkipChat --> CheckMoreChats
    CheckMoreChats -->|Yes| LoopChats
    CheckMoreChats -->|No| CheckMounted{Widget mounted?}
    
    CheckMounted -->|Yes| UpdateState[setState:<br/>_unreadMessageCount = unreadCount]
    CheckMounted -->|No| End2([End])
    UpdateState --> End2
    
    style Start fill:#90EE90
    style End1 fill:#FFB6C1
    style End2 fill:#90EE90
    style CheckParticipant fill:#E6E6FA
    style QueryRecent fill:#FFE4B5
    style Increment fill:#90EE90
    style BreakEarly fill:#FFE4B5
    style UpdateState fill:#90EE90
```

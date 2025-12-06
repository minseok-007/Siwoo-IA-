# 스케줄 알고리즘 사용 위치 상세 설명

## 1. Interval Overlap Detection (구간 겹침 감지)

### 사용 위치
- **파일**: `lib/services/schedule_conflict_service.dart`
- **메서드**: `_intervalsOverlap()` (line 46-53)
- **호출 위치**: `hasConflict()` 메서드 내부 (line 28)

### 정확한 사용 흐름

#### 시나리오 1: 워커가 산책 요청에 지원할 때
```
walk_request_detail_screen.dart (line 168)
  ↓
ScheduleConflictService.hasConflict() 호출
  ↓
기존 산책 목록을 순회하면서 (line 21-36)
  ↓
각 기존 산책과 새 산책의 시간 구간 비교
  ↓
_intervalsOverlap() 호출 (line 28)
  ↓
수식: start1.isBefore(end2) && end1.isAfter(start2)
  ↓
true 반환 시 충돌 감지
```

**예시**:
- 기존 산책: 2024-01-15 10:00 ~ 11:00
- 새 산책: 2024-01-15 10:30 ~ 11:30
- 체크: 10:30 < 11:00 && 11:30 > 10:00 → **true (충돌)**

#### 시나리오 2: 오너가 워커를 선택할 때
```
walk_application_list_screen.dart (line 111)
  ↓
ScheduleConflictService.hasConflict() 호출
  ↓
선택하려는 워커의 기존 산책 목록 가져오기 (line 108)
  ↓
_intervalsOverlap()로 충돌 체크
  ↓
충돌 시 경고 다이얼로그 표시
```

---

## 2. Conflict Severity Score (충돌 심각도 계산)

### 사용 위치
- **파일**: `lib/services/schedule_conflict_service.dart`
- **메서드**: `calculateConflictSeverity()` (line 62-84)
- **호출 위치**: `findConflicts()` 메서드 내부 (line 104)

### 정확한 사용 흐름

```
walk_request_detail_screen.dart (line 175)
  ↓
ScheduleConflictService.findConflicts() 호출
  ↓
각 충돌하는 산책에 대해 (line 99-113)
  ↓
calculateConflictSeverity() 호출 (line 104)
  ↓
수식: overlapDuration / totalDuration
  ↓
0.0 ~ 1.0 사이의 심각도 점수 반환
  ↓
심각도가 높은 순으로 정렬 (line 117)
  ↓
UI에 표시 (빨강: >0.7, 주황: 0.5-0.7)
```

**예시**:
- 산책 A: 10:00-11:00 (60분)
- 산책 B: 10:30-11:30 (60분)
- 겹침: 10:30-11:00 (30분)
- 심각도: 30 / (60 + 60) = **0.25 (25% 겹침)**

---

## 3. Gap Detection (대안 시간 제안)

### 사용 위치
- **파일**: `lib/services/schedule_conflict_service.dart`
- **메서드**: `suggestAlternativeTimes()` (line 128-179)
- **호출 위치**: 
  - `walk_request_detail_screen.dart` (line 181)
  - `walk_application_list_screen.dart` (line 124)

### 정확한 사용 흐름

```
walk_request_detail_screen.dart (line 181)
  ↓
ScheduleConflictService.suggestAlternativeTimes() 호출
  ↓
워커의 기존 산책 목록을 시작 시간 기준 정렬 (line 136-141)
  ↓
간격(Gap) 찾기:
  1. 첫 산책 이전 시간 체크
  2. 산책들 사이의 간격 체크 (line 156-167)
  3. 마지막 산책 이후 시간 체크 (line 170-176)
  ↓
각 간격이 요청된 산책 시간보다 긴지 확인
  ↓
15분 버퍼 추가 (line 160, 161)
  ↓
최대 3개의 대안 시간 반환
  ↓
UI에 제안 시간 표시
```

**예시**:
- 기존 산책: 10:00-11:00, 14:00-15:00
- 요청 산책: 30분
- 대안 제안:
  1. 11:15 (첫 산책 이후)
  2. 15:15 (마지막 산책 이후)

---

## 4. Dynamic Programming (최적 스케줄 계산)

### 사용 위치
- **파일**: `lib/services/optimal_scheduling_service.dart`
- **메서드**: `findOptimalSchedule()` (line 21-132)
- **호출 위치**: `optimal_schedule_screen.dart` (line 97)

### 정확한 사용 흐름

```
optimal_schedule_screen.dart
  ↓
사용자가 "Optimal Schedule" 화면 진입
  ↓
_calculateOptimalSchedule() 호출 (line 94)
  ↓
OptimalSchedulingService.findOptimalSchedule() 호출 (line 97)
  ↓
1단계: 사용 가능한 산책 필터링 (line 36-43)
  - pending 상태만
  - 날짜 범위 내
  
2단계: 종료 시간 기준 정렬 (line 54)
  - DP를 위해 필수
  
3단계: 각 산책에 대해 마지막 비겹침 산책 찾기 (line 67-86)
  - 이진 탐색 사용
  - O(log n) 시간
  
4단계: DP 테이블 채우기 (line 89-108)
  - dp[i] = max(dp[i-1], value[i] + dp[lastNonOverlapping])
  - 각 산책을 포함할지 말지 결정
  
5단계: 역추적으로 선택된 산책 복원 (line 111-122)
  ↓
최적 스케줄 결과 반환
  ↓
UI에 표시 (통계 + 목록)
```

**DP 점화식 상세**:
```dart
// 각 산책 i에 대해:
skipValue = dp[i]  // 이 산책을 포함하지 않을 때의 최대값
includeValue = value[i] + dp[lastNonOverlapping[i] + 1]  // 포함할 때

dp[i + 1] = max(skipValue, includeValue)
```

**예시**:
- 산책 A: 10:00-11:00, 가치 100
- 산책 B: 10:30-11:30, 가치 120 (A와 충돌)
- 산책 C: 12:00-13:00, 가치 80

최적 해: A + C = 180 (B는 A와 충돌하므로 제외)

---

## 전체 플로우 요약

### 워커가 지원할 때
1. **Interval Overlap Detection** → 충돌 여부 확인
2. 충돌 시 **Conflict Severity Score** → 심각도 계산
3. **Gap Detection** → 대안 시간 제안
4. 사용자에게 다이얼로그 표시

### 오너가 워커 선택할 때
1. **Interval Overlap Detection** → 선택한 워커의 충돌 확인
2. 충돌 시 **Conflict Severity Score** → 심각도 계산
3. **Gap Detection** → 대안 시간 제안
4. 경고와 함께 선택 가능

### 워커가 최적 스케줄 보기
1. **Dynamic Programming** → 모든 가능한 조합 중 최적 해 계산
2. 결과를 UI에 표시 (통계 + 목록)

---

## 시간 복잡도 요약

| 알고리즘 | 시간 복잡도 | 실제 호출 빈도 |
|---------|-----------|--------------|
| Interval Overlap Detection | O(n) | 매우 자주 (지원/선택 시마다) |
| Conflict Severity Score | O(1) | 충돌 발견 시 |
| Gap Detection | O(n log n) | 충돌 발견 시 |
| Dynamic Programming | O(n log n + n²) | 사용자가 화면 방문 시 |

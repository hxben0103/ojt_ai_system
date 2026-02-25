# Quick Start Guide - Enhanced Dashboards

## 🚀 Quick Integration

### Step 1: Use Enhanced Student Dashboard

Update `main.dart`:

```dart
import 'dashboards/enhanced_student_dashboard.dart'; // Add this import

// In routes:
'/student': (context) => const EnhancedStudentDashboard(), // Replace StudentDashboard
```

### Step 2: Test the Demo Flows

#### Flow 1: Student Flow (✅ Ready)
1. Login as student
2. Dashboard shows attendance status, AI risk, hours
3. Tap "Record Attendance" → Camera opens
4. Tap "Open OJT Chatbot" → Chatbot opens with session support

#### Flow 2: Supervisor Flow (⚠️ Needs Assignment)
1. Login as supervisor
2. Dashboard shows assigned students (when implemented)
3. Tap student → View details
4. Tap "Submit Evaluations" → Evaluation form opens

#### Flow 3: Coordinator Flow (⚠️ Needs List)
1. Login as coordinator
2. Dashboard shows student list with risk indicators (when implemented)
3. Tap student → View detailed monitoring

---

## 📝 Key Files Modified/Created

### Created
- `widgets/dashboard_card.dart` - Reusable card widget
- `widgets/risk_badge.dart` - Risk level badge
- `core/app_theme.dart` - Centralized theme
- `dashboards/enhanced_student_dashboard.dart` - Enhanced student dashboard

### Modified
- `widgets/chatbot_screen.dart` - Added session_id support

---

## 🎨 Using Reusable Components

### DashboardCard Example

```dart
DashboardCard(
  title: "My Card Title",
  subtitle: "Card description",
  leading: Icon(Icons.star),
  onTap: () => print('Tapped'),
)
```

### RiskBadge Example

```dart
RiskBadge(riskLevel: "HIGH") // Shows red badge
RiskBadge(riskLevel: "MEDIUM", compact: true) // Smaller badge
```

### AppTheme Usage

```dart
Text("Title", style: AppTheme.heading1)
ElevatedButton(
  style: AppTheme.primaryButtonStyle(AppTheme.studentPrimary),
  onPressed: () {},
  child: Text("Button"),
)
```

---

## ⚠️ Mock Data Locations

All mock data is clearly marked with `// TODO:` comments:

1. **Enhanced Student Dashboard**:
   - AI risk level: Lines 134-141 (defaults to "MEDIUM" if API fails)
   - Hours: Lines 162-167 (defaults to 0/300 if API fails)

2. **Future Dashboards**:
   - Will include similar TODO comments for easy identification

---

## 🔧 Troubleshooting

### Chatbot Not Working
- Check `AiConfig.chatEndpoint` is correct
- Verify Flask AI server is running on port 5000
- Check session_id is being sent (check network logs)

### AI Risk Level Shows "MEDIUM" Always
- Verify prediction API is working: `GET /api/prediction/daily/:studentId`
- Check student has OJT record and attendance data
- May need to generate first prediction

### Attendance Not Loading
- Verify attendance API: `GET /api/attendance/today/:studentId`
- Check student has logged attendance
- Verify authentication token is valid

---

**For full details, see `DASHBOARD_IMPROVEMENTS_SUMMARY.md`**


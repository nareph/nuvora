import 'package:hive/hive.dart';
import '../models/user_hive_model.dart';
import '../models/health_profile_hive_model.dart';
import '../models/training_program_hive_model.dart';
import '../models/workout_log_hive_model.dart';
import '../models/nutrition_profile_hive_model.dart';
import '../models/nutrition_plan_hive_model.dart';
import '../models/recovery_status_hive_model.dart';
import '../models/daily_checkin_hive_model.dart';
import '../models/progress_snapshot_hive_model.dart';
import '../models/conversation_hive_model.dart';
import '../models/coach_cache_hive_model.dart';
import '../models/blood_pressure_hive_model.dart';
import '../models/blood_glucose_hive_model.dart';
import '../models/hydration_log_hive_model.dart';
import '../models/mental_wellness_hive_model.dart';
import '../models/habit_hive_model.dart';
import '../models/habit_log_hive_model.dart';
import '../models/nutrition_log_hive_model.dart';

class HiveBoxes {
  static const String users = 'users';
  static const String healthProfiles = 'health_profiles';
  static const String trainingPrograms = 'training_programs';
  static const String weeklyWorkouts = 'weekly_workouts';
  static const String workoutLogs = 'workout_logs';
  static const String currentUser = 'current_user';
  static const String nutritionProfiles = 'nutrition_profiles';
  static const String nutritionPlans = 'nutrition_plans';
  static const String recoveryStatuses = 'recovery_statuses';
  static const String dailyCheckIns = 'daily_checkins';
  static const String progressSnapshots = 'progress_snapshots';
  static const String conversations = 'coach_conversations';
  static const String coachCache = 'coach_cache';
  static const String bloodPressure = 'blood_pressure_readings';
  static const String bloodGlucose = 'blood_glucose_readings';
  static const String hydrationLogs = 'hydration_logs';
  static const String mentalWellness = 'mental_wellness_checkins';
  static const String habits = 'habits';
  static const String habitLogs = 'habit_logs';
  static const String nutritionLogs = 'nutrition_logs';

  static Box<UserHiveModel> get usersBox => Hive.box<UserHiveModel>(users);
  static Box<HealthProfileHiveModel> get healthProfilesBox =>
      Hive.box<HealthProfileHiveModel>(healthProfiles);
  static Box<TrainingProgramHiveModel> get trainingProgramsBox =>
      Hive.box<TrainingProgramHiveModel>(trainingPrograms);
  static Box<WorkoutLogHiveModel> get workoutLogsBox =>
      Hive.box<WorkoutLogHiveModel>(workoutLogs);
  static Box get currentUserBox => Hive.box(currentUser);
  static Box<NutritionProfileHiveModel> get nutritionProfilesBox =>
      Hive.box<NutritionProfileHiveModel>(nutritionProfiles);
  static Box<NutritionPlanHiveModel> get nutritionPlansBox =>
      Hive.box<NutritionPlanHiveModel>(nutritionPlans);
  static Box<RecoveryStatusHiveModel> get recoveryStatusesBox =>
      Hive.box<RecoveryStatusHiveModel>(recoveryStatuses);
  static Box<DailyCheckInHiveModel> get dailyCheckInsBox =>
      Hive.box<DailyCheckInHiveModel>(dailyCheckIns);
  static Box<ProgressSnapshotHiveModel> get progressSnapshotsBox =>
      Hive.box<ProgressSnapshotHiveModel>(progressSnapshots);
  static Box<ConversationHiveModel> get conversationsBox =>
      Hive.box<ConversationHiveModel>(conversations);
  static Box<CoachCacheHiveModel> get coachCacheBox =>
      Hive.box<CoachCacheHiveModel>(coachCache);
  static Box<BloodPressureHiveModel> get bloodPressureBox =>
      Hive.box<BloodPressureHiveModel>(bloodPressure);
  static Box<BloodGlucoseHiveModel> get bloodGlucoseBox =>
      Hive.box<BloodGlucoseHiveModel>(bloodGlucose);
  static Box<HydrationLogHiveModel> get hydrationLogsBox =>
      Hive.box<HydrationLogHiveModel>(hydrationLogs);
  static Box<MentalWellnessHiveModel> get mentalWellnessBox =>
      Hive.box<MentalWellnessHiveModel>(mentalWellness);
  static Box<HabitHiveModel> get habitsBox => Hive.box<HabitHiveModel>(habits);
  static Box<HabitLogHiveModel> get habitLogsBox =>
      Hive.box<HabitLogHiveModel>(habitLogs);
  static Box<NutritionLogHiveModel> get nutritionLogsBox =>
      Hive.box<NutritionLogHiveModel>(nutritionLogs);
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/songs_provider.dart';
import 'providers/match_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/user_profile_provider.dart';
import 'onboarding/onboarding_controller.dart';

// Pages
import 'pages/splash.dart';
import 'pages/chat_page.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait only — no landscape allowed
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await dotenv.load(fileName: 'assets/.env');

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SongsProvider()),
        ChangeNotifierProvider(create: (_) => MatchProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => UserProfileProvider()),
        ChangeNotifierProvider(create: (_) => OnboardingController()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "Wav",
        theme: ThemeData.dark(),
        routes: {
          '/chat': (context) {
            final args = ModalRoute.of(context)!.settings.arguments
                as Map<String, dynamic>;
            final currentUid = args['currentUserId'];
            final otherUid = args['otherUserId'];
            final chatId = currentUid.hashCode <= otherUid.hashCode
                ? "${currentUid}_$otherUid"
                : "${otherUid}_$currentUid";
            return ChatPage(
              chatId: chatId,
              otherUserId: args['otherUserId'],
              otherUsername: args['otherUsername'],
              otherPhotoUrl: args['otherPhotoUrl'],
            );
          },
        },
        home: const SplashScreen(),
      ),
    );
  }
}
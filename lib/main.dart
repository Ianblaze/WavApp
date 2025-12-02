import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Pages
import 'auth/login_page.dart';
import 'pages/chat_page.dart';   // <-- Make sure this path matches your project

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase correctly
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Wav",
      theme: ThemeData.dark(),

      // ------------------------------------------------------------
      //                 ROUTES (Added ChatPage Route)
      // ------------------------------------------------------------
      routes: {
        '/chat': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

          // Create a stable unique chatId for both users
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

      home: const LoginPage(),
    );
  }
}

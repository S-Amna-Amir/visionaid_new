import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:vision_aid/data/services/tts_service.dart';
import 'shared/colors.dart';
import 'pages/splash/splash.dart';
import 'pages/default/page1.dart';
import 'pages/default/page1_urdu.dart';
import 'pages/outputs/output_10n.dart';
import 'pages/model_testing.dart';
import 'pages/assistive/AssistivePage1.dart';
import 'pages/assistive/assist_urdu1.dart';
import 'pages/outputs/unidepth_page.dart';
import 'pages/outputs/assistive_live.dart';
import 'pages/outputs/output_10n2.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TtsService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType)
      {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Flutter Demo',
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/pg1' : (context) => const HomePage2(),
            '/pg1_urdu': (context) => const HomePage2_Urdu(),
            '/yolo10n' : (context) => const YoloV10Output(),
            '/onnx': (context) => const UniDepthPage(),
            '/assist_live': (context) => const AssistiveLivePage(),
            '/modelSelectionPage': (context) => const ModelSelectionPage(),
            '/best_yolo': (context) => const YoloPage(),
            '/instructions1': (context) => InstructionPage(
                instructionText: "Welcome to Assistive Mode Tutorial. Tap once to pause or resume instructions. Swipe left to confirm your choices and continue. Swipe right to go back. ",
                nextRoute: '/instructions2',
                previousRoute: '/pg1',
            ),
            '/instructions2': (context) => InstructionPage(
              instructionText: "Your language is set as English. Long press anywhere on the screen to change to Urdu. "
                  "Swipe right to continue.",
              nextRoute: '/onnx',
              previousRoute: '/pg1',
            ),
            '/instructions_urdu': (context) => InstructionPageU(
              instructionText: "ٹیوٹوریل میں خوش آمدید۔ ہدایات کو روکنے یا دوبارہ شروع کرنے کے لیے ایک بار اسکرین پر کلک کریں۔ اپنے انتخاب کی تصدیق کرنے کے لیے بائیں سوائپ کریں اور جاری رکھیں۔ واپس جانے کے لیے دائیں سوائپ کریں۔",
              nextRoute: '/instructions_urdu2',
              previousRoute: '/pg1_urdu',
            ),
            '/instructions_urdu2': (context) => InstructionPageU(
              instructionText: "زبان اردو کے طور پر مقرر کی گئی ہے۔ انگریزی میں تبدیل کرنے کے لیے اسکرین پر کہیں بھی دیر تک دبائیں۔",
              nextRoute: '/onnx',
              previousRoute: '/pg1_urdu'
            ),
          },
          initialRoute: '/splash',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: darkGreen),
          )
        );
      }
    );
  }

  /*
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Flutter Demo',
    home: Sizer(
      builder: (context, orientation, deviceType)
      {
        return const SplashScreen();
      }
       ),
    initialRoute: '/pg1',
    routes: {
      '/splash': (context) => const SplashScreen(),
      //'/welcome': (context) => const HomePage(),
      '/output': (context) => const OutputPage(),
      '/pg1' : (context) => const HomePage2(),
      '/obj_detect': (context) => const ObjDetector(),
    },
    
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: darkGreen),
    ),
           
          );
  } */
}






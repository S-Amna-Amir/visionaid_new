import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../shared/colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vision_aid/data/services/tts_service.dart';

class HomePage2_Urdu extends StatefulWidget {
  const HomePage2_Urdu({super.key});

  @override
  State<HomePage2_Urdu> createState() => _HomePage2_UrduState();
}

class _HomePage2_UrduState extends State<HomePage2_Urdu> {
  double initialX = 0.0;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await TtsService.instance.init();   // <-- ensure preload ready
      _speakWelcome();
    });
  }

  Future<void> _speakWelcome() async {
    if (_isMuted) return;

    await TtsService.instance.speak(
      "ویژن ایڈ میں خوش آمدید۔ اگلے صفحے پر جانے کے لیے بائیں یا دائیں سوائیپ کریں۔",
      langCode: "ur-IN",
    );
  }

  Future<void> _speakAndNavigate(String text, String route) async {
    if (!_isMuted) {
      await TtsService.instance.speak(
        text,
        langCode: "ur-IN",
      );
    }

    if (!mounted) return;

    // Stop speaking before navigation to avoid overlap
    await TtsService.instance.stop();

    Navigator.pushNamed(context, route);
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkGreen,
      body: GestureDetector(
        onHorizontalDragStart: (details) {
          initialX = details.globalPosition.dx;
        },

        onHorizontalDragEnd: (details) async {
          // Swipe Left
          if (details.primaryVelocity != null &&
              details.primaryVelocity! < 0) {
            _speakAndNavigate(
              "رکاوٹوں کی پہچان والے صفحے پر جا رہے ہیں۔",
              '/output',
            );
          }
          // Swipe Right
          else if (details.primaryVelocity != null &&
              details.primaryVelocity! > 0) {
            _speakAndNavigate(
              "ڈیپتھ ایسٹی میشن والے صفحے پر جا رہے ہیں۔",
              '/onnx',
            );
          }
        },

        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Container(
              width: 90.w,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    "assets/images/logo2.svg",
                    width: 40.w,
                    height: 12.h,
                  ),
                  SizedBox(height: 3.h),

                  Text(
                    "!خوش آمدید",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      color: darkGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4.h),

                  // TEXT MODE
                  Container(
                    width: 70.w,
                    decoration: BoxDecoration(
                      border: Border.all(color: darkGreen, width: 3),
                      borderRadius: BorderRadius.circular(8),
                      color: const Color.fromARGB(255, 242, 247, 231),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Column(
                      children: [
                        Text(
                          "عام موڈ",
                          style: TextStyle(
                            fontSize: 20,
                            color: darkGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkGreen,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 20),
                          ),
                          onPressed: () {
                            TtsService.instance.stop();
                            Navigator.pushReplacementNamed(
                                context, '/instructions_urdu');
                          },
                          child: const Text(
                            "موڈ تبدیل کریں",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 4.h),

                  // LANGUAGE BOX
                  Container(
                    width: 70.w,
                    decoration: BoxDecoration(
                      border: Border.all(color: darkGreen, width: 3),
                      borderRadius: BorderRadius.circular(8),
                      color: const Color.fromARGB(255, 242, 247, 231),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    child: Column(
                      children: [
                        Text(
                          "اردو",
                          style: TextStyle(
                            fontSize: 20,
                            color: darkGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: darkGreen,
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 20),
                          ),
                          onPressed: () {
                            TtsService.instance.stop();
                            Navigator.pushReplacementNamed(context, '/pg1');
                          },
                          child: const Text(
                            "زبان تبدیل کریں",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 4.h),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 20),
                    ),
                    onPressed: () {
                      _speakAndNavigate(
                        "ترتیبات محفوظ کر دی گئی ہیں۔",
                        '/onnx_hafsa',
                      );
                    },
                    child: Text(
                      "ترتیبات کو محفوظ کریں",
                      style: TextStyle(
                          color: darkGreen, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

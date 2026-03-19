import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../../shared/colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:vision_aid/data/services/tts_service.dart';

class HomePage2 extends StatefulWidget {
  const HomePage2({super.key});

  @override
  State<HomePage2> createState() => _HomePage2State();
}

class _HomePage2State extends State<HomePage2> {
  double initialX = 0.0;

  bool _isMuted = false;
  bool _isEnglish = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _speakWelcome();
    });
  }

  Future<void> _speakWelcome() async {
    if (_isMuted) return;

    String text = _isEnglish
        ? "Welcome to Vision Aid. Swipe left to continue to obstacle detection model. Swipe right to continue to depth estimation model."
        : "ویژن ایڈ میں خوش آمدید۔ اگلے صفحے پر جانے کے لیے بائیں یا دائیں سوائیپ کریں۔";

    await TtsService.instance.speak(
      text,
      langCode: _isEnglish ? "en-US" : "ur-PK",
    );
  }

  Future<void> _speakAndNavigate(
      String englishText, String urduText, String route) async {
    if (!_isMuted) {
      await TtsService.instance.speak(
        _isEnglish ? englishText : urduText,
        langCode: _isEnglish ? "en-US" : "ur-PK",
      );
    }

    if (!mounted) return;
    Navigator.pushNamed(context, route);
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);

    if (_isMuted) {
      TtsService.instance.stop();
    } else {
      _speakWelcome();
    }
  }

  /// When user taps language button → go to Urdu version page
  void _switchToUrduPage() {
    TtsService.instance.stop();
    Navigator.pushReplacementNamed(context, '/pg1_urdu');
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
          if (details.primaryVelocity != null && details.primaryVelocity! < 0) {
            await _speakAndNavigate(
              "Moving to the obstacle detection page.",
              "رکاوٹوں کی پہچان والے صفحے پر جا رہے ہیں۔",
              '/yolo10n',
            );
          } else if (details.primaryVelocity != null &&
              details.primaryVelocity! > 0) {
            await _speakAndNavigate(
              "Moving to the depth estimation page.",
              "ڈیپتھ ایسٹی میشن والے صفحے پر جا رہے ہیں۔",
              '/onnx',
            );
          }
        },
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
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
                          SizedBox(height: 2.h),

                          Text(
                            "Welcome To\nVision Aid",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              color: darkGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4.h),

                          // TEXT MODE BOX
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
                                  "Text Mode",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: darkGreen,
                                    fontWeight: FontWeight.w500,
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
                                    Navigator.pushNamed(
                                        context, '/instructions1');
                                  },
                                  child: const Text(
                                    "CHANGE",
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
                                  _isEnglish ? "English" : "اردو",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: darkGreen,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 10),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: darkGreen,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 20),
                                  ),
                                  onPressed: _switchToUrduPage,
                                  child: const Text(
                                    "CHANGE",
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
                              backgroundColor: Colors.white,
                              side: BorderSide(color: darkGreen, width: 2),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 20),
                            ),
                            onPressed: () {
                              Navigator.pushNamed(
                                  context, '/modelSelectionPage');
                            },
                            child: Text(
                              "Model Testing",
                              style: TextStyle(
                                color: darkGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          SizedBox(height: 1.h),
                          ElevatedButton(style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: BorderSide(color: darkGreen, width: 2),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 20),
                            ),
                            onPressed: () {
                              Navigator.pushNamed(
                                  context, '/modelSelectionPage');
                            },
                            child: Text(
                              "Continue",
                              style: TextStyle(
                                color: darkGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),)
                        ],
                      ),
                    ),
                  ],
                ),

                // TOP RIGHT: MUTE + LANGUAGE
                Positioned(
                  top: 10,
                  right: 10,
                  child: Column(
                    children: [
                      IconButton(
                        icon: Icon(
                          _isMuted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: _toggleMute,
                      ),
                      SizedBox(height: 12),
                      IconButton(
                        icon: Icon(
                          Icons.language,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: _switchToUrduPage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

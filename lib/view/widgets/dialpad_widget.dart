import 'package:flutter/material.dart';
import 'package:telnyx_flutter_webrtc/utils/dimensions.dart';
import 'package:telnyx_flutter_webrtc/utils/theme.dart';

class DialPad extends StatefulWidget {
  final ValueChanged<String>? onDigitPressed;

  const DialPad({
    Key? key,
    this.onDigitPressed,
  }) : super(key: key);

  @override
  _DialPadState createState() => _DialPadState();
}

class _DialPadState extends State<DialPad> {
  final TextEditingController _controller = TextEditingController();

  /// All standard dialpad digits
  final List<String> _digits = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '*',
    '0',
    '#',
  ];

  void _handleDigitPress(String digit) {
    widget.onDigitPressed?.call(digit);
    setState(() {
      _controller.text += digit;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      color: surfaceColor,
      padding: const EdgeInsets.symmetric(
        vertical: spacingL,
        horizontal: spacingXXL,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: [
                Text(
                  'DTMF Dialpad',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            TextField(
              controller: _controller,
              readOnly: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: fontSizeXL, color: Colors.black),
              decoration: const InputDecoration(
                border: InputBorder.none,
              ),
            ),

            const SizedBox(height: spacingM),

            // 3x4 grid of digit buttons
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _digits.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: spacingS,
                crossAxisSpacing: spacingS,
              ),
              itemBuilder: (context, index) {
                final digit = _digits[index];
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: telnyx_soft_black,
                    backgroundColor: call_control_color,
                    padding: const EdgeInsets.all(spacingL),
                  ),
                  onPressed: () => _handleDigitPress(digit),
                  child: Text(
                    digit,
                    style: const TextStyle(fontSize: fontSizeL),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

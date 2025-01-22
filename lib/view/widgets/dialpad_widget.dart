import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_masked_text2/flutter_masked_text2.dart';

class DialPad extends StatefulWidget {
  final ValueSetter<String>? makeCall;
  final ValueSetter<String>? keyPressed;
  final bool? hideDialButton;

  // buttonColor is the color of the button on the dial pad. defaults to Colors.gray
  final Color? buttonColor;
  final Color? buttonTextColor;
  final Color? dialButtonColor;
  final Color? dialButtonIconColor;
  final IconData? dialButtonIcon;
  final Color? backspaceButtonIconColor;
  final Color? dialOutputTextColor;

  // outputMask is the mask applied to the output text. Defaults to (000) 000-0000
  final String? outputMask;

  const DialPad({
    super.key,
    this.makeCall,
    this.keyPressed,
    this.hideDialButton,
    this.outputMask,
    this.buttonColor,
    this.buttonTextColor,
    this.dialButtonColor,
    this.dialButtonIconColor,
    this.dialButtonIcon,
    this.dialOutputTextColor,
    this.backspaceButtonIconColor,
  });

  @override
  DialPadState createState() => DialPadState();
}

class DialPadState extends State<DialPad> {
  MaskedTextController? textEditingController;
  var _value = '';
  var mainTitle = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '＃'];
  var subTitle = [
    '',
    'ABC',
    'DEF',
    'GHI',
    'JKL',
    'MNO',
    'PQRS',
    'TUV',
    'WXYZ',
    null,
    '+',
    null,
  ];

  @override
  void initState() {
    textEditingController =
        MaskedTextController(mask: widget.outputMask ?? '(000) 000-0000');
    super.initState();
  }

  void _setText(String? value) async {
    if (widget.keyPressed != null) widget.keyPressed!(value!);

    setState(() {
      _value += value!;
      textEditingController!.text = _value;
    });
  }

  List<Widget> _getDialerButtons() {
    final rows = <Widget>[];
    var items = <Widget>[];

    for (var i = 0; i < mainTitle.length; i++) {
      if (i % 3 == 0 && i > 0) {
        rows
          ..add(
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: items,
            ),
          )
          ..add(
            const SizedBox(
              height: 12,
            ),
          );
        items = <Widget>[];
      }

      items.add(
        DialButton(
          title: mainTitle[i],
          subtitle: subTitle[i],
          color: widget.buttonColor,
          textColor: widget.buttonTextColor,
          onTap: _setText,
        ),
      );
    }
    rows
      ..add(
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: items),
      )
      ..add(
        const SizedBox(
          height: 12,
        ),
      );

    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final sizeFactor = screenSize.height * 0.09852217;

    return Center(
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextFormField(
              readOnly: true,
              style: TextStyle(
                color: widget.dialOutputTextColor ?? Colors.black,
                fontSize: sizeFactor / 2,
              ),
              textAlign: TextAlign.center,
              decoration: const InputDecoration(border: InputBorder.none),
              controller: textEditingController,
            ),
          ),
          ..._getDialerButtons(),
          const SizedBox(
            height: 15,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              Expanded(
                child: Container(),
              ),
              Expanded(
                child: widget.hideDialButton != null && widget.hideDialButton!
                    ? Container()
                    : Center(
                        child: DialButton(
                          icon: widget.dialButtonIcon ?? Icons.phone,
                          color: widget.dialButtonColor != null
                              ? widget.dialButtonColor!
                              : Colors.green,
                          onTap: (value) {
                            widget.makeCall!(_value);
                          },
                        ),
                      ),
              ),
              Expanded(
                child: Padding(
                  padding:
                      EdgeInsets.only(right: screenSize.height * 0.03685504),
                  child: IconButton(
                    icon: Icon(
                      Icons.backspace,
                      size: sizeFactor / 2,
                      color: _value.isNotEmpty
                          ? (widget.backspaceButtonIconColor ?? Colors.white24)
                          : Colors.white24,
                    ),
                    onPressed: _value.isEmpty
                        ? null
                        : () {
                            if (_value.isNotEmpty) {
                              setState(() {
                                _value = _value.substring(0, _value.length - 1);
                                textEditingController!.text = _value;
                              });
                            }
                          },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DialButton extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final Color? color;
  final Color? textColor;
  final IconData? icon;
  final Color? iconColor;
  final ValueSetter<String?>? onTap;
  final bool? shouldAnimate;

  const DialButton({
    super.key,
    this.title,
    this.subtitle,
    this.color,
    this.textColor,
    this.icon,
    this.iconColor,
    this.shouldAnimate,
    this.onTap,
  });

  @override
  DialButtonState createState() => DialButtonState();
}

class DialButtonState extends State<DialButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation _colorTween;
  Timer? _timer;

  @override
  void initState() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _colorTween =
        ColorTween(begin: widget.color ?? Colors.white24, end: Colors.white)
            .animate(_animationController);

    super.initState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
    if ((widget.shouldAnimate == null || widget.shouldAnimate!) &&
        _timer != null) _timer!.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final sizeFactor = screenSize.height * 0.09852217;

    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) widget.onTap!(widget.title);

        if (widget.shouldAnimate == null || widget.shouldAnimate!) {
          if (_animationController.status == AnimationStatus.completed) {
            _animationController.reverse();
          } else {
            _animationController.forward();
            _timer = Timer(const Duration(milliseconds: 200), () {
              setState(() {
                _animationController.reverse();
              });
            });
          }
        }
      },
      child: ClipOval(
        child: AnimatedBuilder(
          animation: _colorTween,
          builder: (context, child) => Container(
            color: _colorTween.value,
            height: sizeFactor,
            width: sizeFactor,
            child: Center(
              child: widget.icon == null
                  ? widget.subtitle != null
                      ? SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const SizedBox(
                                height: 8,
                              ),
                              Text(
                                widget.title!,
                                style: TextStyle(
                                  fontSize: sizeFactor / 2,
                                  color: widget.textColor ?? Colors.black,
                                ),
                              ),
                              Text(
                                widget.subtitle!,
                                style: TextStyle(
                                  color: widget.textColor ?? Colors.black,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Padding(
                          padding: EdgeInsets.only(
                            top: widget.title == '*' ? 10 : 0,
                          ),
                          child: Text(
                            widget.title!,
                            style: TextStyle(
                              fontSize:
                                  widget.title == '*' && widget.subtitle == null
                                      ? screenSize.height * 0.0862069
                                      : sizeFactor / 2,
                              color: widget.textColor ?? Colors.black,
                            ),
                          ),
                        )
                  : Icon(
                      widget.icon,
                      size: sizeFactor / 2,
                      color: widget.iconColor ?? Colors.white,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

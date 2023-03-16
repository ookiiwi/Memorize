import 'package:flutter/material.dart';

class TextFieldDialog extends StatefulWidget {
  const TextFieldDialog(
      {Key? key,
      this.controller,
      this.hintText,
      this.confirmText,
      this.cancelText,
      required this.hasConfirmed})
      : super(key: key);

  final String? hintText;
  final TextEditingController? controller;
  final String? confirmText;
  final String? cancelText;

  /// If returned value != null, it is displayed as an error message
  final String? Function(bool value) hasConfirmed;

  @override
  State<StatefulWidget> createState() => _TextFieldDialog();
}

class _TextFieldDialog extends State<TextFieldDialog> {
  String? get hintText => widget.hintText;
  TextEditingController? get controller => widget.controller;
  String? get confirmText => widget.confirmText;
  String? get cancelText => widget.cancelText;
  String? Function(bool value) get hasConfirmed => widget.hasConfirmed;
  String? _errorMessage;

  Widget _buildDialog() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          fillColor: Colors.transparent,
          filled: true,
          hintText: hintText,
          errorText: _errorMessage,
        ),
      ),
    );
  }

  Widget _buildConfirmBtn({required bool value, required String text}) {
    return ConfirmationButton(
      text: text,
      onTap: () {
        _errorMessage = hasConfirmed(value);

        if (_errorMessage != null) {
          setState(() {});
          return;
        }

        controller?.clear();
        Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      elevation: 0,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              color: Colors.white,
            ),
            child: _buildDialog(),
          ),
          Padding(
            padding: const EdgeInsets.all(5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildConfirmBtn(value: false, text: cancelText ?? 'Cancel'),
                const SizedBox(width: 20),
                _buildConfirmBtn(value: true, text: confirmText ?? 'Confirm'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ConfirmationButton extends StatelessWidget {
  const ConfirmationButton({Key? key, required this.onTap, required this.text})
      : super(key: key);

  final void Function() onTap;
  final String text;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primaryContainer;
    final onPrimaryColor = Theme.of(context).colorScheme.onPrimaryContainer;

    return GestureDetector(
      onTap: () {
        onTap();
      },
      child: Container(
        height: 50,
        width: 100,
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(color: onPrimaryColor),
          ),
        ),
      ),
    );
  }
}

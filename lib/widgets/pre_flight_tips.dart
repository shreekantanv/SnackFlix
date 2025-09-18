import 'package:flutter/material.dart';

class PreFlightTips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Pre-Flight Tips'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• Good lighting'),
          Text('• Face visible in camera'),
          Text('• Snack/utensil ready'),
        ],
      ),
      actions: <Widget>[
        TextButton(
          child: Text('Continue'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

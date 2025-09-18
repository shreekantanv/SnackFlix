import 'package:flutter/material.dart';

class ExitConfirmDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('End session?'),
      content: Text('Are you sure you want to end the session?'),
      actions: <Widget>[
        TextButton(
          child: Text('Continue'),
          onPressed: () {
            Navigator.of(context).pop(false);
          },
        ),
        TextButton(
          child: Text('End'),
          onPressed: () {
            Navigator.of(context).pop(true);
          },
        ),
      ],
    );
  }
}

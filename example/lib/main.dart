import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:vap/vap.dart';

main() {
  runApp(MaterialApp(home: Application()));
}

class Application extends StatelessWidget {
  const Application({super.key});

  @override
  Widget build(BuildContext context) {
    late VapController controller;
    return Scaffold(
      appBar: AppBar(title: Text('VapView Example')),
      body: Center(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: List.generate(
                  20,
                  (index) => SizedBox(
                    width: 300,
                    height: 300,
                    child: VapView(
                      repeat: -1,
                      mute: true,
                      onViewCreated: (ctl) async {
                        controller = ctl;
                        controller.playAsset('assets/sample.mp4').then((value) {
                          log("KEREN");
                        });
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

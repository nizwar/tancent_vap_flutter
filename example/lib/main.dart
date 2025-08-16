import 'package:flutter/material.dart';
import 'package:tancent_vap/tancent_vap.dart';

main() {
  runApp(MaterialApp(home: Application()));
}

class Application extends StatefulWidget {
  const Application({super.key});

  @override
  State<Application> createState() => _ApplicationState();
}

class _ApplicationState extends State<Application> {
  late VapController controller;
  final TextEditingController textController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                spacing: 20,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: textController,
                    decoration: InputDecoration(
                      labelText: "Enter text to replace [sTxt1]",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      controller.setVapTagContent(
                          "[sTxt1]", TextContent(textController.text));
                      controller.playAsset("assets/vapx.mp4");
                    },
                    child: Text("Play Animation"),
                  ),
                ],
              ),
            ),
          ),

          // IgnorePointer to prevent user interaction with the VapView
          // This is useful if you want to display the animation without allowing user interaction.
          // You can remove this IgnorePointer if you want the VapView to be interactive.
          IgnorePointer(
            child: VapView(
              repeat: 0, // 0 means play once, -1 means loop infinitely
              mute: true, // Mute the audio
              scaleType: ScaleType.centerCrop, // Scale type for the video
              vapTagContents: {
                "[sTxt1]": TextContent("Nizwar win the game!"),
                "[sImg1]": ImageAssetContent("assets/user.png"),
              },
              onViewCreated: (ctl) async {
                controller = ctl;
              },
            ),
          ),
        ],
      ),
    );
  }
}

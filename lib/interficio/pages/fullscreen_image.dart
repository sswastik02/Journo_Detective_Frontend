import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class FullScreenImage extends StatelessWidget {
  FullScreenImage(this.imageUrl);

  final String imageUrl;
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        child: Stack(
          children: [
            PhotoView(
              loadingBuilder: (context, event) => CircularProgressIndicator(),
              imageProvider: NetworkImage(imageUrl),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: TextButton(
                child: Icon(Icons.arrow_back_ios, color: Colors.white),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

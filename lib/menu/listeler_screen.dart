import 'package:flutter/material.dart';
import 'pages/afro_house_page.dart';
import 'pages/indie_dance_page.dart';
import 'pages/organic_house_page.dart';
import 'pages/down_tempo_page.dart';
import 'pages/melodic_house_page.dart';

class ListelerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final buttonHeight = screenHeight / 7;

    return Scaffold(
      appBar: AppBar(
        title: Text('Listeler', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildImageListButton(
              context,
              buttonHeight,
              'assets/afra.jpeg',
              AfroHousePage(),
            ),
            SizedBox(height: 20),
            _buildImageListButton(
              context,
              buttonHeight,
              'assets/indie.jpg',
              IndieDancePage(),
            ),
            SizedBox(height: 20),
            _buildImageListButton(
              context,
              buttonHeight,
              'assets/organic.jpeg',
              OrganicHousePage(),
            ),
            SizedBox(height: 20),
            _buildImageListButton(
              context,
              buttonHeight,
              'assets/down.jpg',
              DownTempoPage(),
            ),
            SizedBox(height: 20),
            _buildImageListButton(
              context,
              buttonHeight,
              'assets/melodic.jpg',
              MelodicHousePage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageListButton(
      BuildContext context,
      double height,
      String imagePath,
      Widget page,
      ) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => page),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.3),
                  BlendMode.darken,
                ),
              ),
              borderRadius: BorderRadius.circular(height * 0.1),
            ),
          ),
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.all(Colors.transparent),
            elevation: MaterialStateProperty.resolveWith<double>(
                  (Set<MaterialState> states) {
                if (states.contains(MaterialState.hovered)) return 10;
                if (states.contains(MaterialState.pressed)) return 5;
                return 6;
              },
            ),
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(height * 0.1),
              ),
            ),
            overlayColor: MaterialStateProperty.all(Colors.white.withOpacity(0.15)),
            padding: MaterialStateProperty.all(EdgeInsets.zero),
            animationDuration: Duration(milliseconds: 200),
            shadowColor: MaterialStateProperty.all(Colors.black.withOpacity(0.5)),
          ),
        ),
      ),
    );
  }
}
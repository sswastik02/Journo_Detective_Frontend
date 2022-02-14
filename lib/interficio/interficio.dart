import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './pages/home_page.dart';
import './pages/authentication.dart';

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Map<String, dynamic> user = {
    "name": "",
    "username": "",
    "token": "",
    "isAuthenticated": false,
    "email": "",
    "password": ""
  };

  bool _isLoading = false;

  void autoAuthenticate() async {
    setState(() {
      _isLoading = true;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // prefs.clear(); //remove this to save user data
    var _token = prefs.getString("token");
    print(_token);
    if (_token != null) {
      setState(() {
        user["isAuthenticated"] = true;
        user["username"] = prefs.getString("username");
        user["token"] = prefs.getString("token");
        user["email"] = prefs.getString("email");
        user["password"] = prefs.getString("password");
        user["name"] = prefs.getString("name");
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  DatabaseReference _databaseReference;
  bool comingsoon = false;

  @override
  void initState() {
    autoAuthenticate();
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark));
  }

  @override
  Widget build(BuildContext context) {
    // return WillPopScope(
    //   onWillPop: () {
    //     SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    //         statusBarColor: Colors.transparent,
    //         systemNavigationBarIconBrightness: Brightness.dark));
    //     Navigator.pop(context);
    //   },
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      //debugShowMaterialGrid: true,
      theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: Colors.red,
          accentColor: Colors.green),
      routes: {
        "/": (BuildContext context) => _isLoading
            ? Container()
            : comingsoon
                ? Scaffold(
                    body: Material(
                      child: Container(
                        height: MediaQuery.of(context).size.height,
                        child: Image.asset("images/comingsoon.png",
                            fit: BoxFit.cover),
                      ),
                    ),
                  )
                : user["isAuthenticated"]
                    ? HomePage(user)
                    : AuthPage(user),
      },
    );
  }
}

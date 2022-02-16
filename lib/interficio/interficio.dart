import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import './pages/home_page.dart';
import './pages/authentication.dart';

class Interfecio extends StatefulWidget {
  const Interfecio({Key key}) : super(key: key);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<Interfecio> {
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
    print("TOKEN : $_token");
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

  bool comingsoon = false;

  @override
  void initState() {
    autoAuthenticate();
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
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
      ),
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

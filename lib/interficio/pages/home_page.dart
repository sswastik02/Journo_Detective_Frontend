// ignore_for_file: deprecated_member_use, avoid_print

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:photo_view/photo_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:journo/util/inner_drawer.dart';
import 'fullscreen_image.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> user;
  HomePage(this.user);

  @override
  _HomePageState createState() => _HomePageState(user);
}

String apiUrl = "interficio.herokuapp.com";

bool header = false;
bool intro = false;
ValueNotifier<double> lat, long;

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final Map<String, dynamic> user;
  _HomePageState(this.user);

  var currentLocation = LocationData;
  var location = Location();
  var accuracy;
  SharedPreferences _sharedPrefs;
  bool _finalAnswerGiven = false;

  Map<String, dynamic> levelData = {}; //stores data of current level of user
  Map<String, dynamic> clueData = {};
  Map<String, dynamic> unlockedClueData = {};
  var mainQues;
  var finalAns;

  List<dynamic> leaderboard; //stores the current leaderboard

  final _answerFieldController =
      TextEditingController(); //to retrieve textfield value

  final _fieldFocusNode = new FocusNode(); //to deselect answer textfield

  bool _isLoading = false;

  // void getLocation() async {
  //   PermissionStatus perm = await location.hasPermission();
  //   print(perm);
  //   LocationData currentLocation = await location.getLocation();
  //   location.changeSettings(accuracy: LocationAccuracy.HIGH);
  //   setState(
  //     () {
  //       location.onLocationChanged().listen(
  //         (LocationData currentLocation) {
  //           setState(
  //             () {
  //               lat = currentLocation.latitude;
  //               long = currentLocation.longitude;
  //               accuracy = currentLocation.accuracy;
  //             },
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

//this function retrieves the data of the current level of the user
  Future getLevelData() async {
    setState(() {
      _isLoading = true;
    });

    http.Response response = await http.get(
        Uri.parse("https://$apiUrl/api/getlevel/"),
        headers: {"Authorization": "Token ${user["token"]}"});
    levelData = json.decode(response.body);
    print("DATA LEVEL DATA : $levelData");

    if (levelData["level"] == "ALLDONE")
      clueData = {"data": "finished"};
    else if (levelData["pause_bool"] == true) {
      levelData["level"] = "More Levels Coming Soon";
      clueData = {"data": "finished"};
    } else {
      dynamic level = levelData["level_no"];
      print("LEVELNO:$level");
      SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString("currentLevel", "$level");
      http.Response clues = await http.get(
          Uri.parse("https://$apiUrl/api/getlevelclues/?level_no=$level"),
          headers: {"Authorization": "Token ${user["token"]}"});
      clueData = json.decode(clues.body);
      print("DATA cluesData: $clueData");
    }

    print(clueData);
    setState(() {
      _isLoading = false;
    });
  }

  Future getUnclockedClues() async {
    setState(() {
      _isLoading = true;
    });
    print("start");
    http.Response response = await http
        .get(Uri.parse("https://$apiUrl/api/getclues/"), headers: {
      "Authorization": "Token ${user["token"]}",
      "Content-type": "application/json"
    });
    print("done");

    setState(() {
      unlockedClueData = json.decode(response.body);
      _isLoading = false;
    });

    print("DATA unlockedClue $unlockedClueData");
  }

  Future getMainQuestion() async {
    setState(() {
      _isLoading = true;
    });
    print("main");
    http.Response response = await http
        .get(Uri.parse("https://$apiUrl/api/finaltext/"), headers: {
      "Authorization": "Token ${user["token"]}",
      "Content-type": "application/json"
    });
    mainQues = json.decode(response.body);
    print("DATA Main Questions : $mainQues");

    setState(() {
      _isLoading = false;
    });
  }

  Future submitFinalAnswer(answer) async {
    setState(() {
      _isLoading = true;
    });
    http.Response response = await http.post(
        Uri.parse("https://$apiUrl/api/finaltext/"),
        headers: {
          "Authorization": "Token ${user["token"]}",
          "Content-type": "application/json"
        },
        body: json.encode({"ans": answer}));
    print(response.body);
    finalAns = json.decode(response.body);
    if (finalAns["success"] == false)
      _scaffoldKey.currentState.showSnackBar(
        const SnackBar(
          content: const Text("Answer already submitted once"),
          duration: const Duration(seconds: 1),
        ),
      );
    // else if (finalAns["success"] == true) {
    //   SharedPreferences prefs = await SharedPreferences.getInstance();
    //   prefs.setString("success", "true");
    // }
    setState(() {
      _sharedPrefs.setBool("finalAnswerGiven", true);
      _finalAnswerGiven = true;
      _isLoading = false;
    });
  }

//this function retrieves the current leaderboard
  Future getScoreboard() async {
    setState(() {
      _isLoading = true;
    });
    http.Response response = await http.get(
        Uri.parse("https://$apiUrl/api/scoreboard/"),
        headers: {"Authorization": "Token ${user["token"]}"});
    leaderboard = json.decode(response.body);
    print("DATA LEADERBOARD $leaderboard");
    setState(() {
      _isLoading = false;
    });
  }

  Future unlockClue(clueNo) async {
    setState(() {
      _isLoading = true;
    });

    http.Response response = await http.get(
        Uri.parse(
            "https://$apiUrl/api/unlockclue/?level_no=${levelData["level_no"]}&clue_no=$clueNo"),
        headers: {"Authorization": "Token ${user["token"]}"}).then((onValue) {
      getLevelData();
      getUnclockedClues();
    });

    print(json.decode(response.body));

    setState(() {
      _isLoading = false;
    });
  }

//this function submits the current location of the user
  Future submitLocation() async {
    setState(() {
      _isLoading = true;
    });
    // if (accuracy > 25) {
    //   _scaffoldKey.currentState.showSnackBar(SnackBar(
    //     content: Text("location not accurate enough. please try again"),
    //     duration: Duration(seconds: 1),
    //   ));
    // } else {
    http.Response response = await http.post(
      Uri.parse("https://$apiUrl/api/submit/location/"),
      headers: {
        "Authorization": "Token ${user["token"]}",
        "Content-Type": "application/json"
      },
      body: json.encode({
        "lat": lat.value,
        "long": long.value,
        "level_no": levelData["level_no"],
      }),
    );
    var data = json.decode(response.body);

    _scaffoldKey.currentState.showSnackBar(SnackBar(
      content: Text(data["success"] == true ? "correct location" : "try again"),
      duration: const Duration(seconds: 1),
    ));
    // }
    setState(() {
      getLevelData().then((onValue) {
        getUnclockedClues();
      });
    });
  }

  void setIntro() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("intro", "true");
  }

  void getIntro() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var temp = prefs.getString("intro");
    if (temp == "true") intro = true;
  }

  Widget _answerTextField() {
    return TextFormField(
      controller: _answerFieldController,
      style: TextStyle(
        color: Colors.white.withOpacity(0.7),
      ),
      decoration: InputDecoration(
        suffixIcon: Icon(
          Icons.question_answer,
          color: Colors.white.withOpacity(0.7),
        ),
        // filled: true,
        // fillColor: Colors.white.withOpacity(0.7),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: Color(0xC0FF9e02), //Color of the border
            style: BorderStyle.solid, //Style of the border
            width: 1, //width of the border
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: Color(0xC0FF9e02), //Color of the border
            style: BorderStyle.solid, //Style of the border
            width: 1, //width of the border
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        labelText: "answer",
        labelStyle: TextStyle(
          color: Colors.white.withOpacity(0.7),
        ),
      ),
      validator: (String value) {
        if (value.trim().isEmpty) {
          return "Please enter a valid answer";
        }
      },
      onSaved: (String value) {},
    );
  }

  @override
  void dispose() {
    _answerFieldController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((value) {
      setState(() {
        _sharedPrefs = value;
        _finalAnswerGiven = _sharedPrefs.get("finalAnswerGiven");
        print("DATA FINAL ANSWER GIVEN : $_finalAnswerGiven");
      });
    });
    getIntro();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // getLocation();
    // getMainQuestion();
    lat = ValueNotifier<double>(0.0);
    long = ValueNotifier<double>(0.0);
    lat.addListener(() {
      setState(() {});
    });
    long.addListener(() {
      setState(() {});
    });
    getLevelData().then((val) {
      getScoreboard().then((onValue) {
        getUnclockedClues().then((onValue) {
          getMainQuestion();
        });
      });
    });
    // getMainQuestion();
  }

  final LabeledGlobalKey<InnerDrawerState> _innerDrawerKey =
      LabeledGlobalKey<InnerDrawerState>("label");

  void _toggle() {
    _innerDrawerKey.currentState.toggle(
        // direction is optional
        // if not set, the last direction will be used
        //InnerDrawerDirection.start OR InnerDrawerDirection.end
        direction: InnerDrawerDirection.start);
  }

  bool _isUp =
      true; //to maintain state of the animation of leaderboard, instruction sheet
  bool _isOpen = false; //to maintain animation of question, answer box

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  //for bottomsnackbar

  Widget drawerClues() {
    return _isLoading
        ? Container(
            child: const CircularProgressIndicator(),
          )
        : Material(
            color: Colors.white.withOpacity(0),
            child: Column(
              children: <Widget>[
                Container(
                  color: Colors.black,
                  alignment: Alignment.topLeft,
                  padding: const EdgeInsets.all(10),
                  child: const FittedBox(
                    child: Text(
                      "CURRENT CLUES",
                      style: TextStyle(
                          fontFamily: "Mysterious",
                          color: Color(0xFFFF9e02),
                          fontSize: 35,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                clueData["data"] == "finished"
                    ? Container()
                    : Expanded(
                        child: Container(
                          // height: MediaQuery.of(context).size.height / 3,
                          padding: const EdgeInsets.fromLTRB(0, 25, 0, 0),
                          color: Colors.black,
                          child: ListView.builder(
                            physics: const ScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: clueData["data"].length ?? 0,
                            itemBuilder: (BuildContext context, int index) {
                              return Container(
                                decoration: const BoxDecoration(
                                    color: Color(0xFF000000),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black,
                                          offset: Offset(2.0, 2.0),
                                          blurRadius: 10.0,
                                          spreadRadius: 1.0),
                                      //   BoxShadow(
                                      //       color: Colors.white,
                                      //       offset: Offset(-2.0, -2.0),
                                      //       blurRadius: 10.0,
                                      //       spreadRadius: 1.0),
                                    ],
                                    borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(20),
                                        bottomRight:
                                            const Radius.circular(20))),
                                margin:
                                    const EdgeInsets.fromLTRB(0, 15, 30, 15),
                                // padding: EdgeInsets.all(10),
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    topRight: Radius.circular(15.0),
                                    bottomRight: const Radius.circular(15.0),
                                  ),
                                  child: ListTile(
                                    tileColor: Colors.white.withOpacity(0.2),
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 5.0, horizontal: 15),
                                    leading: IconButton(
                                      iconSize: 25.0,
                                      color: clueData["data"][index][2] != null
                                          ? Colors.green
                                          : const Color(0xFF03A062),
                                      onPressed: clueData["data"][index][2] ==
                                              null
                                          ? () {
                                              showDialog(
                                                context: context,
                                                builder: (context) => Dialog(
                                                  backgroundColor: Colors.white
                                                      .withOpacity(0),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFF03A062),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              30),
                                                    ),
                                                    padding:
                                                        const EdgeInsets.all(
                                                            15),
                                                    height: 150,
                                                    width:
                                                        MediaQuery.of(context)
                                                                .size
                                                                .width /
                                                            1.5,
                                                    child: Column(
                                                      children: <Widget>[
                                                        const Text(
                                                          "Are you sure you want to unlock this clue?",
                                                          style: TextStyle(
                                                              fontSize: 20,
                                                              color:
                                                                  Colors.white),
                                                        ),
                                                        ButtonBar(
                                                          children: <Widget>[
                                                            // ignore: deprecated_member_use
                                                            OutlineButton(
                                                              borderSide:
                                                                  const BorderSide(
                                                                color: Colors
                                                                    .white, //Color of the border
                                                                style: BorderStyle
                                                                    .solid, //Style of the border
                                                                width:
                                                                    1, //width of the border
                                                              ),
                                                              child: Text(
                                                                "UNLOCK",
                                                              ),
                                                              onPressed: () {
                                                                setState(() {
                                                                  unlockClue(clueData[
                                                                          "data"]
                                                                      [
                                                                      index][0]);
                                                                  Navigator.of(
                                                                          context,
                                                                          rootNavigator:
                                                                              true)
                                                                      .pop(
                                                                          true);
                                                                });
                                                              },
                                                            ),
                                                            OutlineButton(
                                                              borderSide:
                                                                  const BorderSide(
                                                                color: Colors
                                                                    .white, //Color of the border
                                                                style: BorderStyle
                                                                    .solid, //Style of the border
                                                                width:
                                                                    1, //width of the border
                                                              ),
                                                              child: Text(
                                                                "GO BACK",
                                                              ),
                                                              onPressed: () {
                                                                Navigator.of(
                                                                        context,
                                                                        rootNavigator:
                                                                            true)
                                                                    .pop(true);
                                                              },
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }
                                          : () {},
                                      icon: Icon(
                                          clueData["data"][index][2] != null
                                              ? Icons.lock_open
                                              : Icons.lock,
                                          color: Color(0xFFff80a4)),
                                    ),
                                    title: clueData["data"][index][2] != null
                                        ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                "${clueData["data"][index][1]}",
                                                style: const TextStyle(
                                                    color:
                                                        const Color(0xFFff80a4),
                                                    fontSize: 20.0),
                                              ),
                                              Text(
                                                "${clueData["data"][index][2]}",
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 20.0),
                                              ),
                                              const SizedBox(
                                                height: 15.0,
                                              ),
                                              clueData["data"][index][4] != null
                                                  ? GestureDetector(
                                                      onTap: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) =>
                                                                FullScreenImage(
                                                              "https://${apiUrl}${clueData["data"][index][4]}",
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      child: Image.network(
                                                        "https://${apiUrl}${clueData["data"][index][4]}",
                                                        height: 200.0,
                                                        fit: BoxFit.cover,
                                                        loadingBuilder:
                                                            (BuildContext
                                                                    context,
                                                                Widget child,
                                                                ImageChunkEvent
                                                                    loadingProgress) {
                                                          if (loadingProgress ==
                                                              null) {
                                                            return child;
                                                          }
                                                          return Center(
                                                            child:
                                                                CircularProgressIndicator(
                                                              value: loadingProgress
                                                                          .expectedTotalBytes !=
                                                                      null
                                                                  ? loadingProgress
                                                                          .cumulativeBytesLoaded /
                                                                      loadingProgress
                                                                          .expectedTotalBytes
                                                                  : null,
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    )
                                                  : Container(),
                                            ],
                                          )
                                        : Text(
                                            clueData["data"][index][1],
                                            style: TextStyle(
                                                color: const Color(0xFF03A062),
                                                fontSize: 20),
                                          ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                Container(
                  padding: const EdgeInsets.all(10),
                  color: Colors.black,
                  child: const FittedBox(
                    child: Text(
                      "UNLOCKED CLUES",
                      style: TextStyle(
                          fontFamily: "Mysterious",
                          color: Color(0xFFFF9e02),
                          fontSize: 35,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    // height: MediaQuery.of(context).size.height / 2.5,
                    padding: const EdgeInsets.fromLTRB(0, 25, 0, 0),
                    color: Colors.black,
                    child: ListView.builder(
                        shrinkWrap: true,
                        physics: const ScrollPhysics(),
                        itemCount: unlockedClueData.length != null
                            ? unlockedClueData["data"].length
                            : 0,
                        itemBuilder: (BuildContext context, int index) {
                          if (unlockedClueData["data"][index][2] != null) {
                            return Container(
                              decoration: const BoxDecoration(
                                  color: Color(0xFF000000),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black,
                                        offset: Offset(2.0, 2.0),
                                        blurRadius: 10.0,
                                        spreadRadius: 1.0),
                                    // BoxShadow(
                                    //     color: Colors.white,
                                    //     offset: Offset(-2.0, -2.0),
                                    //     blurRadius: 10.0,
                                    //     spreadRadius: 1.0),
                                  ],
                                  borderRadius: BorderRadius.only(
                                      topRight: Radius.circular(20),
                                      bottomRight: Radius.circular(20))),
                              margin: const EdgeInsets.fromLTRB(0, 15, 30, 15),
                              // padding: EdgeInsets.all(10),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(15.0),
                                  bottomRight: Radius.circular(15.0),
                                ),
                                child: ListTile(
                                  tileColor: Colors.white.withOpacity(0.2),
                                  contentPadding: const EdgeInsets.symmetric(
                                      vertical: 5.0, horizontal: 15),
                                  // leading: IconButton(
                                  //   color: Color(0xFFa94064),
                                  //   onPressed: () {},
                                  //   icon: Icon(Icons.vpn_key),
                                  // ),
                                  title: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        "${unlockedClueData["data"][index][1]} \n",
                                        style: const TextStyle(
                                            color: Color(0xFFff80a4),
                                            fontSize: 20),
                                      ),
                                      Text(
                                        "${unlockedClueData["data"][index][2]}",
                                        style: const TextStyle(
                                            color: Colors.white, fontSize: 17),
                                      ),
                                      const SizedBox(
                                        height: 15.0,
                                      ),
                                      unlockedClueData["data"][index][4] != null
                                          ? GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        FullScreenImage(
                                                      "https://${apiUrl}${unlockedClueData["data"][index][4]}",
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: Image.network(
                                                "https://${apiUrl}${unlockedClueData["data"][index][4]}",
                                                height: 200.0,
                                                fit: BoxFit.cover,
                                                loadingBuilder:
                                                    (BuildContext context,
                                                        Widget child,
                                                        ImageChunkEvent
                                                            loadingProgress) {
                                                  if (loadingProgress == null) {
                                                    return child;
                                                  }
                                                  return Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                      value: loadingProgress
                                                                  .expectedTotalBytes !=
                                                              null
                                                          ? loadingProgress
                                                                  .cumulativeBytesLoaded /
                                                              loadingProgress
                                                                  .expectedTotalBytes
                                                          : null,
                                                    ),
                                                  );
                                                },
                                              ),
                                            )
                                          : Container(),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          } else
                            return Container();
                        }),
                  ),
                ),
              ],
            ),
          );
  }

  @override
  Widget build(BuildContext context) {
    var deviceSize = MediaQuery.of(context).size;

//animation using animatedpositioned. mean position toggle values
    double bottom = _isUp ? 65.0 : (deviceSize.height / 2);
    double top = _isUp
        ? (_isOpen ? deviceSize.height / 4 : (deviceSize.height * 3 / 4))
        : bottom;
    double top2 =
        _isUp ? (deviceSize.height - 90) : ((deviceSize.height) / 2) + 10;
    var bottom3 = _isUp ? deviceSize.height : ((deviceSize.height) / 2) + 10;
    var bottom4 = _isUp ? 10.0 : deviceSize.height - 110;
    var right4 = 20.0;

    return levelData["level_no"] == 1 && intro == false
        ? _isLoading
            ? Container(
                color: Colors.white,
                height: MediaQuery.of(context).size.height,
                child: Image.asset("assets/loader1.gif"),
              )
            : Scaffold(
                body: Container(
                  padding: const EdgeInsets.all(30),
                  decoration: const BoxDecoration(
                    color: Color(0xFF000000),
                  ),
                  child: Center(
                    child: SafeArea(
                      child: ListView(
                        children: <Widget>[
                          const Center(
                            child: Text(
                              "The Mystery",
                              style: TextStyle(
                                  fontFamily: 'Mysterious',
                                  color: Color(0xFFFF9e02),
                                  fontSize: 50),
                            ),
                          ),
                          const SizedBox(
                            height: 30,
                          ),
                          Text(
                            mainQues["data"],
                            style: TextStyle(color: Colors.white, fontSize: 27),
                          ),
                          const SizedBox(
                            height: 30,
                          ),
                          FlatButton(
                            padding: const EdgeInsets.symmetric(vertical: 10.0),
                            color: const Color(0xFF03A062),
                            child: const Text(
                              "Proceed",
                              style: TextStyle(
                                fontFamily: 'Mysterious',
                                fontSize: 25.0,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                intro = true;
                                setIntro();
                              });
                            },
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              )
        : WillPopScope(
            // ignore: missing_return
            onWillPop: () {
              SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                  systemNavigationBarIconBrightness: Brightness.dark));
              Navigator.pop(context);
            },
            child: SafeArea(
              child: InnerDrawer(
                key: _innerDrawerKey,
                onTapClose: true, // default false
                swipe: true, // default true
                colorTransition:
                    const Color(0xFF87ceeb), // default Color.black54

                // DEPRECATED: use offset
                leftOffset: 0.3, // Will be removed in 0.6.0 version
                // rightOffset: 0.6, // Will be removed in 0.6.0 version

                //When setting the vertical offset, be sure to use only top or bottom
                offset: IDOffset.only(bottom: 0.2, right: 0.5, left: 0.5),

                // DEPRECATED:  use scale
                leftScale: 0.9, // Will be removed in 0.6.0 version
                rightScale: 0.9, // Will be removed in 0.6.0 version

                scale: IDOffset.horizontal(
                    0.8), // set the offset in both directions

                proportionalChildArea: true, // default true
                borderRadius: 50, // default 0
                leftAnimationType:
                    InnerDrawerAnimation.static, // default static
                rightAnimationType: InnerDrawerAnimation.quadratic,

                // Color(0xFFa94064).withOpacity(0.8),
                // Color(0xFF191970).withOpacity(0.7)
                backgroundColor: const Color(0xFF000000),

                onDragUpdate: (double val, InnerDrawerDirection direction) {
                  print(val);
                  print(direction == InnerDrawerDirection.start);
                },
                innerDrawerCallback: (a) {
                  _animationController.value == 0
                      ? _animationController.forward()
                      : _animationController.reverse();
                },
                leftChild: Container(
                  color: Colors.white.withOpacity(0),
                  child: _isLoading ? Container() : drawerClues(),
                ),

                scaffold: Scaffold(
                  key: _scaffoldKey,
                  resizeToAvoidBottomInset: false,

                  // drawer: AppBar(automaticallyImplyLeading: false,),
                  body: Stack(
                    children: <Widget>[
                      const GameMap(),
                      Padding(
                        padding: const EdgeInsets.all(15),
                        child: IconButton(
                          iconSize: 35,
                          onPressed: () {
                            _toggle();
                            _animationController.value == 1
                                ? _animationController.forward()
                                : _animationController.reverse();
                          },
                          icon: AnimatedIcon(
                              color: Color(0xFF420000),
                              progress: _animationController,
                              icon: AnimatedIcons.menu_close),
                        ),
                      ), //google map as main background of the app
                      AnimatedPositioned(
                        //top instructions panel
                        bottom: bottom3,
                        right: 0.0,
                        left: 0.0,
                        top: -15.0,
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutQuart,
                        child: Center(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutQuart,
                            opacity: _isUp ? 0.5 : 0.8,
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Color(0xFF420000).withOpacity(0.9),
                                // boxShadow: [
                                //   BoxShadow(
                                //       color: Colors.black.withOpacity(0.5),
                                //       offset: Offset.zero,
                                //       blurRadius: 10,
                                //       spreadRadius: 5),
                                // ],
                                // gradient: LinearGradient(
                                //   begin: Alignment.topCenter,
                                //   end: Alignment.bottomCenter,
                                //   stops: [0.5, 0.8, 1.0],
                                //   colors: [
                                //     Colors.grey[900],
                                //     Colors.grey[600],
                                //     Colors.grey
                                //   ],
                                // ),
                                borderRadius: BorderRadius.circular(17),
                              ),
                              child: Container(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 25, 10, 10),
                                alignment: Alignment.topLeft,
                                child: ListView(
                                  children: <Widget>[
                                    const Text(
                                      "INSTRUCTIONS",
                                      style: const TextStyle(
                                          fontFamily: 'Mysterious',
                                          color: Color(0xFFFF9e02),
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(
                                      height: 15,
                                    ),
                                    Text(
                                      "The rules of Journo Detective are as follows: \n\n\n 1) Participants need to solve a murder mystery with the help of an available storyline and clues provided to them.\n\n 2) Each level comprises of a clue to the next location at which the participant can move to the next level. The location can be selected by tapping on the corresponding region on the map, following which a Marker is placed there. Once the Marker is placed, click on submit. If you are at the right location, you progress to the next level.\n\n 3) At every level, there will be a set of clues. You can unlock clues as you desire at a particular location.\n\n 4) A clue that has not been unlocked cannot be unlocked once you pass that level.\n\n 5) The final level requires you to write the name of the criminal with a justification for the same.\n\n 6) The dynamic scoreboard will be based on the level a participant is at and the time he/she takes to reach there.\n\n 7) The final standing will be subjected to three parameters: The correct answer and justification, time taken and number of clues unlocked to come to a conclusion.",
                                      style: TextStyle(fontSize: 17),
                                    ),
                                    const SizedBox(
                                      height: 15,
                                    ),
                                    const Text(
                                      "The Mystery",
                                      style: TextStyle(
                                          fontFamily: 'Mysterious',
                                          color: Colors.red,
                                          fontSize: 32.0),
                                    ),
                                    const SizedBox(
                                      height: 5,
                                    ),
                                    _isLoading
                                        ? Container()
                                        : Text(
                                            mainQues["data"],
                                            style: TextStyle(fontSize: 19),
                                          ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      AnimatedPositioned(
                        //level box displayed on home page
                        bottom: bottom,
                        right: 10.0,
                        left: 10.0,
                        top: top,
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.bounceOut,
                        child: Center(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutQuart,
                            opacity: _isUp ? (_isOpen ? 1 : 0.8) : 0.0,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isOpen = !_isOpen;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.5),
                                        offset: Offset.zero,
                                        blurRadius: 10,
                                        spreadRadius: 5),
                                  ],
                                  color: const Color(0xFF420000),
                                  borderRadius: BorderRadius.circular(17),
                                ),
                                child: Stack(
                                  children: <Widget>[
                                    Positioned(
                                      top: 0.0,
                                      left: 0.0,
                                      right: 0.0,
                                      child: _isLoading
                                          ? Container(
                                              padding: const EdgeInsets.only(
                                                  right: 20),
                                              child: const Center(
                                                  child:
                                                      CircularProgressIndicator()))
                                          : levelData["level"] == "ALLDONE"
                                              ? const Center(
                                                  child: Text(
                                                    "Solve the mystery",
                                                    style: TextStyle(
                                                      fontFamily: 'Mysterious',
                                                      // fontWeight:
                                                      //     FontWeight.bold,
                                                      fontSize: 25.0,
                                                    ),
                                                  ),
                                                )
                                              : levelData["level"] ==
                                                      "More Levels Coming Soon"
                                                  ? const Center(
                                                      child: Text(
                                                          "More Levels Coming Soon"))
                                                  : Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceEvenly,
                                                      children: <Widget>[
                                                        SingleChildScrollView(
                                                          child: Text(
                                                            "${levelData["title"]}  🚩",
                                                            style: TextStyle(
                                                              fontFamily:
                                                                  'Mysterious',
                                                              color: _isOpen
                                                                  ? const Color(
                                                                      0xFFFF9e02)
                                                                  : Colors
                                                                      .white,
                                                              fontSize: 30.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 15,
                                                        ),
                                                        Text(
                                                          "Level: ${levelData["level_no"]}",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 17,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        )
                                                      ],
                                                    ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _isLoading
                          ? Container(
                              // padding: EdgeInsets.only(right: 20),
                              // child: CircularProgressIndicator(),
                              )
                          : AnimatedPositioned(
                              //question along with textfield for answer and submit button
                              top: _isOpen && _isUp
                                  ? deviceSize.height / 2.5
                                  : deviceSize.height + 5.0,
                              bottom: _isOpen && _isUp ? 75.0 : -5.0,
                              left: 20.0,
                              right: 20.0,
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutQuart,
                              child: GestureDetector(
                                onTap: () {
                                  FocusScope.of(context)
                                      .requestFocus(FocusNode());
                                },
                                child: Center(
                                  child: ScrollConfiguration(
                                    behavior: MyBehavior(),
                                    child: levelData["level"] == "ALLDONE"
                                        ? ListView(
                                            children: <Widget>[
                                              Container(
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xC0FF9e02),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 7,
                                                        horizontal: 15),
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 10,
                                                        horizontal: 10),
                                                child: Text(
                                                  mainQues["data"],
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              _finalAnswerGiven != null &&
                                                      _finalAnswerGiven
                                                  ? Container()
                                                  : _answerTextField(),
                                              const SizedBox(
                                                height: 10,
                                              ),
                                              _finalAnswerGiven != null &&
                                                      _finalAnswerGiven
                                                  ? Center(
                                                      child: Container(
                                                        child: Text(
                                                          "Final Answer Submitted",
                                                          style: TextStyle(
                                                            fontSize: 22.0,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  : OutlineButton(
                                                      borderSide:
                                                          const BorderSide(
                                                        color: Color(
                                                            0xFFa94064), //Color of the border
                                                        style: BorderStyle
                                                            .solid, //Style of the border
                                                        width:
                                                            1, //width of the border
                                                      ),
                                                      color: const Color(
                                                          0xFF0059B3),
                                                      child: const Text(
                                                        "SUBMIT ANSWER",
                                                        style: TextStyle(
                                                          fontFamily:
                                                              'Mysterious',
                                                          // fontWeight:
                                                          //     FontWeight.bold,
                                                          fontSize: 20.0,
                                                        ),
                                                      ),
                                                      onPressed: () {
                                                        submitFinalAnswer(
                                                            _answerFieldController
                                                                .value.text);
                                                        _answerFieldController
                                                            .clear();
                                                      },
                                                    ),
                                            ],
                                          )
                                        : ListView(
                                            children: <Widget>[
                                              Container(
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFFF9e02),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 7,
                                                        horizontal: 15),
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 5,
                                                        horizontal: 10),
                                                child: Text(
                                                  '${levelData["ques"]}',
                                                  style: TextStyle(
                                                      color: _isOpen
                                                          ? Colors.white
                                                          : Colors.white,
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w500),
                                                ),
                                              ),
                                              ListTile(
                                                // title: levelData["map_hint"]
                                                //     ?
                                                title: Center(
                                                  child: Column(
                                                    children: <Widget>[
                                                      const SizedBox(
                                                        height: 20,
                                                      ),
                                                      const FittedBox(
                                                        child: Text(
                                                          "YOUR CURRENT LOCATION",
                                                          maxLines: 1,
                                                          style: TextStyle(
                                                            fontFamily:
                                                                'Mysterious',
                                                            color: Colors.white,
                                                            fontSize: 300,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: 20,
                                                      ),
                                                      ListTile(
                                                        leading: const Icon(
                                                          Icons
                                                              .subdirectory_arrow_left,
                                                          color:
                                                              Color(0xFFff80a4),
                                                        ),
                                                        title: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            const Text(
                                                              "LATITUDE: ",
                                                              style: TextStyle(
                                                                  color: Color(
                                                                      0xFFff80a4)),
                                                            ),
                                                            Text(
                                                              "${lat.value == 0.0 ? 'None' : lat.value.toStringAsFixed(8) + ' °N'}",
                                                            )
                                                          ],
                                                        ),
                                                      ),
                                                      ListTile(
                                                        leading: const Icon(
                                                          Icons
                                                              .subdirectory_arrow_right,
                                                          color:
                                                              Color(0xFFff80a4),
                                                        ),
                                                        title: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            const Text(
                                                              "LONGITUDE: ",
                                                              style: TextStyle(
                                                                  color: Color(
                                                                      0xFFff80a4)),
                                                            ),
                                                            Text(
                                                              "${long.value == 0.0 ? 'None' : long.value.toStringAsFixed(8) + ' °E'}",
                                                            )
                                                          ],
                                                        ),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              ButtonBar(
                                                alignment: MainAxisAlignment
                                                    .spaceEvenly,
                                                children: [
                                                  TextButton(
                                                    style: ButtonStyle(
                                                        padding:
                                                            MaterialStateProperty
                                                                .all(EdgeInsets
                                                                    .all(12)),
                                                        shape: MaterialStateProperty.all(
                                                            RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12))),
                                                        backgroundColor:
                                                            MaterialStateProperty.all(
                                                                Color(0xFF1178d8))),
                                                    child: const Text(
                                                      "GET CLUES",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontFamily:
                                                            'Mysterious',
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 22.0,
                                                      ),
                                                    ),
                                                    onPressed: () {
                                                      setState(() {
                                                        _toggle();
                                                      });
                                                    },
                                                  ),
                                                  // borderSide:
                                                  //       const BorderSide(
                                                  //     color: Color(
                                                  //         0xFF03A062), //Color of the border
                                                  //     style: BorderStyle
                                                  //         .solid, //Style of the border
                                                  //     width:
                                                  //         1, //width of the border
                                                  //   ),
                                                  TextButton(
                                                    style: ButtonStyle(
                                                        padding:
                                                            MaterialStateProperty
                                                                .all(EdgeInsets
                                                                    .all(12)),
                                                        shape: MaterialStateProperty.all(
                                                            RoundedRectangleBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            12))),
                                                        backgroundColor:
                                                            MaterialStateProperty.all(
                                                                Color(0xFF128000))),
                                                    child: const Text(
                                                      "SUBMIT",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontFamily:
                                                            'Mysterious',
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 20.0,
                                                      ),
                                                    ),
                                                    onPressed: () {
                                                      setState(() {
                                                        submitLocation();
                                                      });
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            ),
                      AnimatedPositioned(
                        //leaderboard generated dynamically using listview.builder
                        bottom: -15.0,
                        right: 0.0,
                        left: 0.0,
                        top: top2,
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutQuart,
                        child: Center(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutQuart,
                            opacity: _isUp ? 0.8 : 1,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  print("leader");
                                  _isUp = !_isUp;
                                  getScoreboard();
                                });
                              },
                              onVerticalDragStart: (context) {
                                setState(() {
                                  print("leader");
                                  _isUp = !_isUp;
                                  getScoreboard();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 20),
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.5),
                                        offset: Offset.zero,
                                        blurRadius: 10,
                                        spreadRadius: 5),
                                  ],
                                  color:
                                      const Color(0xFF420000).withOpacity(0.7),
                                  // gradient: LinearGradient(
                                  //   begin: Alignment.topCenter,
                                  //   end: Alignment.bottomCenter,
                                  //   stops: [0.3, 1.0],
                                  //   // Color(0xFFa94064).withOpacity(0.8),
                                  //   // Color(0xFF191970).withOpacity(0.7)
                                  //   // Color(0xFF0091FF), Color(0xFF0059FF)
                                  //   colors: [
                                  //     Color(0xFF191970),
                                  //     Color(0xFFa94064),
                                  //   ],
                                  // ),
                                  borderRadius: BorderRadius.circular(17),
                                ),
                                child: ListView.builder(
                                  itemCount: leaderboard == null
                                      ? 0
                                      : leaderboard.length + 2,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    if (index == 0) {
                                      return Center(
                                        child: Text(
                                          "LEADERBOARD",
                                          style: TextStyle(
                                            fontFamily: "Mysterious",
                                            fontSize: 36.0,
                                            color: _isUp
                                                ? Colors.white
                                                : const Color(0xFFFF9e02),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    } else if (index == 1) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 10.0),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: const <Widget>[
                                            // SizedBox(width: 40),
                                            Text(
                                              "Name",
                                              style: TextStyle(
                                                  fontFamily: 'Mysterious',
                                                  fontSize: 28,
                                                  color: Color(0xFFdb1896)),
                                            ),
                                            Text(
                                              "Level",
                                              style: TextStyle(
                                                  fontFamily: 'Mysterious',
                                                  fontSize: 28,
                                                  color: Color(0xFFdb1896)),
                                            )
                                          ],
                                        ),
                                      );
                                    } else {
                                      return Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: <Widget>[
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                "${index - 1}",
                                                style: TextStyle(
                                                    fontSize: 23,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              const SizedBox(
                                                width: 20,
                                              ),
                                              Text(
                                                leaderboard[index - 2]["name"],
                                                style: TextStyle(
                                                    fontSize: 23,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            "${leaderboard[index - 2]["current_level"]}",
                                            style: TextStyle(
                                                fontSize: 23,
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      );
                                    }
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // AnimatedPositioned(
                      //   //leaderboard icon that triggers animation
                      //   bottom: deviceSize.height - top2 - 25,
                      //   left: 20,
                      //   top: top2 - 35,
                      //   duration: Duration(milliseconds: 1200),
                      //   curve: Curves.easeOutQuart,
                      //   child: GestureDetector(
                      //     onVerticalDragStart: (context) {
                      //       setState(() {
                      //         _isUp = !_isUp;
                      //         // getScoreboard();
                      //       });
                      //     },
                      //     child: Icon(
                      //       Icons.assessment,
                      //       color: Colors.white,
                      //       size: 50,
                      //     ),
                      //   ),
                      // ),
                      // AnimatedPositioned(
                      //   //info icon that triggers animation
                      //   bottom: bottom4,
                      //   right: right4,
                      //   duration: Duration(milliseconds: 1200),
                      //   curve: Curves.easeOutQuart,
                      //   child: GestureDetector(
                      //     onTap: () {
                      //       setState(() {
                      //         print("he");
                      //         _isUp = !_isUp;
                      //         // getScoreboard();
                      //       });
                      //     },
                      //     // onVerticalDragStart: (context) {
                      //     //   setState(() {
                      //     //     print("he");
                      //     //     _isUp = !_isUp;
                      //     //     getScoreboard();
                      //     //   });
                      //     // },
                      //     child: Icon(
                      //       Icons.info,
                      //       color: Colors.white,
                      //       size: 50,
                      //     ),
                      //   ),
                      // ),
                      Positioned(
                        top: 25.0,
                        right: 15.0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8.0, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Color(0xFF420000).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          // height: 100.0,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    print("he");
                                    _isUp = !_isUp;
                                    getScoreboard();
                                  });
                                },
                                // onVerticalDragStart: (context) {
                                //   setState(() {
                                //     print("he");
                                //     _isUp = !_isUp;
                                //     getScoreboard();
                                //   });
                                // },
                                child: const Icon(
                                  Icons.info,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(
                                height: 20.0,
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    print("he");
                                    _isUp = !_isUp;
                                    getScoreboard();
                                  });
                                },
                                // onVerticalDragStart: (context) {
                                //   setState(() {
                                //     print("he");
                                //     _isUp = !_isUp;
                                //     getScoreboard();
                                //   });
                                // },
                                child: const Icon(
                                  Icons.assessment,
                                  color: Colors.white,
                                  size: 40,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
  }
}

class GameMap extends StatefulWidget {
  const GameMap({Key key}) : super(key: key);

  @override
  _GameMapState createState() => _GameMapState();
}

class _GameMapState extends State<GameMap> {
  BitmapDescriptor pinLocationIcon;
  Completer<GoogleMapController> mapController = Completer();
  final List _markers = [];
  final LatLng initialPosition = const LatLng(39.8283, -98.5795);
  LatLng currentPosition = const LatLng(39.8283, -98.5795);
  @override
  void initState() {
    BitmapDescriptor.fromAssetImage(
            ImageConfiguration(devicePixelRatio: 2.5), 'assets/detective.png')
        .then((pin) {
      pinLocationIcon = pin;
      _markers.add(
        Marker(
            markerId: MarkerId(
              "start",
            ),
            position: initialPosition,
            consumeTapEvents: true,
            infoWindow: InfoWindow(
                title:
                    "${initialPosition.latitude}°N,  ${initialPosition.longitude}°E"),
            icon: pin),
      );
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          myLocationButtonEnabled: true,
          initialCameraPosition: CameraPosition(
            target: initialPosition,
            zoom: 3.5,
          ),
          markers: Set.from(_markers),
          onMapCreated: _onMapCreated,
          myLocationEnabled: false,
          compassEnabled: false,
          zoomControlsEnabled: false,
          onCameraMove: (position) {
            setState(() {
              currentPosition = position.target;
              _handleTap(position.target);
            });
          },
        ),
        Positioned(
          width: 0.5 * MediaQuery.of(context).size.width,
          height: 0.15 * MediaQuery.of(context).size.width,
          left: 0.25 * (MediaQuery.of(context).size.width),
          top: 0.1 * (MediaQuery.of(context).size.height),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                  0.15 * MediaQuery.of(context).size.width),
            ),
            color: Color(0xFF420000).withOpacity(0.5),
            child: Center(
              child: FittedBox(
                child: Text(
                  "${currentPosition.latitude.toStringAsFixed(3)}°N,  ${currentPosition.longitude.toStringAsFixed(3)}°E",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: MediaQuery.of(context).size.width * 0.01,
          bottom: MediaQuery.of(context).size.height * 0.5,
          width: 0.15 * MediaQuery.of(context).size.width,
          height: 0.15 * MediaQuery.of(context).size.width,
          child: GestureDetector(
            onTap: () async {
              (await mapController.future).animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(target: initialPosition, zoom: 3.5),
                ),
              );
            },
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                    0.15 * MediaQuery.of(context).size.width),
              ),
              color: Color(0xFF420000).withOpacity(0.5),
              child: const Center(
                child: Text(
                  "R",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        )
      ],
    );
  }

  void _setStyle(GoogleMapController controller) async {
    String value = await DefaultAssetBundle.of(context)
        .loadString('assets/maps_style.json');
    controller.setMapStyle(value);
  }

  _onMapCreated(GoogleMapController controller) {
    setState(() {
      _setStyle(controller);
      mapController.complete(controller);
    });
  }

  void _handleTap(LatLng point) {
    if (_markers.isNotEmpty) _markers.removeLast();
    setState(() {
      lat.value = point.latitude;
      long.value = point.longitude;
      _markers.add(
        Marker(
            markerId: MarkerId(
              point.toString(),
            ),
            position: point,
            icon: pinLocationIcon),
      );
      currentPosition = point;
    });
  }
}

class MyBehavior extends ScrollBehavior {
  @override
  Widget buildViewportChrome(
      BuildContext context, Widget child, AxisDirection axisDirection) {
    return child;
  }
}

import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:rxdart/rxdart.dart';
import 'package:permission_handler/permission_handler.dart' as permission;
import 'dart:async';
import 'info.dart';
import 'dart:ui' as ui;
// import 'package:background_location/background_location.dart' as background;

class MapsPage extends StatefulWidget {
  final User? user;
  const MapsPage({Key? key, this.user}) : super(key: key);

  @override
  _MapsPageState createState() => _MapsPageState();
}

enum LocationPermissionStatus { granted, denied, permanentlyDenied, restricted }

class _MapsPageState extends State<MapsPage> {
  // 自分の現在地
  late GeoPoint _myPosition = const GeoPoint(0, 0);

  // 現在位置の変化を監視
  StreamSubscription? _locationChangedListen;

  // 現在位置
  LocationData? _yourLocation;

  // 自分のid
  String _myId = "";

  // 自分が所属しているサブグループ
  List<dynamic> _mySubgroupIds = [];
  // 自分が所属しているグループ
  String _myGroup = "";

  // アイコン
  late BitmapDescriptor blueIcon;
  late BitmapDescriptor lightBlueIcon;
  late BitmapDescriptor redIcon;

  // google mapのコントローラー
  late GoogleMapController mapController;

  // locationのインスタンス
  Location location = Location();
  User? currentUser;

  // コルーチン用のフラグ
  bool _looding = true;

  int _notificationCount = 0;

  // firestoreのインスタンスを取得
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  Future<void> getUserInfo(User? user) async {
    DocumentSnapshot userSnapshot =
        await firestore.collection("USERS").doc(user!.uid.toString()).get();
    setState(() {
      _myGroup = userSnapshot.get("currentGroupId");
      _mySubgroupIds = userSnapshot.get("currentSubgroupId");
      _myId = userSnapshot.get("userId");
    });
  }

  @override
  void initState() {
    super.initState();
    // _getCurrentLocation();
    makeIcon();
    currentUser = widget.user;
    getUserInfo(widget.user!).then((val) {
      whileRequest().then((value) {
        if (value == LocationPermissionStatus.granted) {
          alwaysRequest();
          _getCurrentLocation();
          update();
        } else {
          showDialog(
              context: context,
              builder: (context) => AlertDialog(
                    title: const Text("位置情報の許可が必要です"),
                    content: const Text("設定画面から位置情報の許可をしてください"),
                    actions: [
                      TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text("OK"))
                    ],
                  ));
        }
      });
    });
  }

  // show current location
  showCurrentLocation() async {
    mapController.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: LatLng(_myPosition.latitude, _myPosition.longitude),
      zoom: 16.0,
    )));
  }

  showGroupLocation() async {
    DocumentSnapshot groupSnapshot =
        await firestore.collection("GROUPS").doc(_myGroup).get();
    GeoPoint dest = groupSnapshot.get("destination");
    mapController.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
      target: LatLng(dest.latitude, dest.longitude),
      zoom: 16.0,
    )));
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  makeIcon() {
    getBytesFromAsset("assets/images/blue_circle.png", 40).then((val) {
      setState(() {
        blueIcon = BitmapDescriptor.fromBytes(val);
      });
    });
    getBytesFromAsset("assets/images/light_blue_circle.png", 40).then((val) {
      setState(() {
        lightBlueIcon = BitmapDescriptor.fromBytes(val);
      });
    });
    getBytesFromAsset("assets/images/red_circle.png", 40).then((val) {
      setState(() {
        redIcon = BitmapDescriptor.fromBytes(val);
      });
    });
  }

  Future<void> update() async {
    await location.enableBackgroundMode(enable: true);

    _locationChangedListen = location.onLocationChanged.listen((event) async {
      _getNotificationCount();
      setState(() {
        _yourLocation = event;
        _myPosition =
            GeoPoint(_yourLocation!.latitude!, _yourLocation!.longitude!);
      });

      firestore.collection("USERS").doc(_myId).update({
        "location":
            GeoPoint(_yourLocation!.latitude!, _yourLocation!.longitude!)
      });
    });
  }

  @override
  void dispose() {
    super.dispose();

    _locationChangedListen?.cancel();
  }

  _getNotificationCount() async {
    QuerySnapshot querySnapshot = await firestore
        .collection("INVITES")
        .where("toId", isEqualTo: widget.user!.uid)
        .get();
    setState(() {
      _notificationCount = querySnapshot.docs.length;
    });
  }

  // 現在の座標を取得
  _getCurrentLocation() async {
    try {
      // 自分の座標を取得
      LocationData currentLocation = await location.getLocation();
      setState(() {
        _myPosition = GeoPoint(currentLocation.latitude as double,
            currentLocation.longitude as double);
      });

      // データベースに保存
      firestore
          .collection("USERS")
          .doc(widget.user!.uid)
          .update({"location": _myPosition});

      setState(() {
        _looding = false;
      });
    } catch (e) {
      print('Could not get the location: $e');
    }
  }

  // サブグループが同じかどうか
  bool _isMatchSubgroups(QueryDocumentSnapshot user) {
    for (String id in _mySubgroupIds) {
      List<dynamic> subgroupIds = user.get("currentSubgroupId");
      if (subgroupIds.contains(id)) {
        return true;
      }
    }
    return false;
  }

  // マーカーを作成する
  Stream<Set<Marker>> _makeMarkers() {
    // グループに属していない時の処理
    if (_myGroup == "") {
      Set<Marker> myMarker = {};
      myMarker.add(Marker(
        markerId: MarkerId(_myId),
        position: LatLng(_myPosition.latitude, _myPosition.longitude),
        icon: redIcon,
      ));

      // setState(() {
      //   _makingMarker = false;
      // });

      return Stream.value(myMarker);
    }

    // メイングループの目的地のマーカーを作成
    var mainGroupSnapshot =
        firestore.collection("GROUPS").doc(_myGroup).snapshots();
    var mainDestMarker = mainGroupSnapshot.map((event) {
      GeoPoint dest = event.get("destination");

      Set<Marker> marker = {};

      marker.add(Marker(
        markerId: MarkerId(_myGroup),
        infoWindow: InfoWindow(title: "目的地：${event.get("name")}"),
        position: LatLng(dest.latitude, dest.longitude),
      ));

      return marker;
    });

    // グループメンバーのマーカーを作成
    var usersRef = firestore
        .collection("USERS")
        .where("currentGroupId", isEqualTo: _myGroup)
        .snapshots();
    var memberMarkers = usersRef.map((event) =>
        event.docs.map((e) => _convertToMarker(e, mainGroupSnapshot)).toSet());

    // ストリームを繋げる
    var mergeStream1 = Rx.combineLatest2(
        memberMarkers, mainDestMarker, (a, b) => a.followedBy(b).toSet());

    // サブグループがなかったら、飛ばす
    if (_mySubgroupIds.isEmpty) {
      // setState(() {
      //   _makingMarker = false;
      // });

      return mergeStream1;
    }
    // サブグループの目的地のマーカーを作成
    var subgroupSnapshot = firestore
        .collection("GROUPS")
        .where("groupId", whereIn: _mySubgroupIds)
        .snapshots();
    var subDestMarker = subgroupSnapshot.map((event) => event.docs.map((e) {
          String id = e.get("groupId");
          GeoPoint dest = e.get("destination");

          return Marker(
              markerId: MarkerId(id),
              position: LatLng(dest.latitude, dest.longitude),
              infoWindow: InfoWindow(title: "サブグループ：${e.get("name")}"),
              icon: BitmapDescriptor.defaultMarkerWithHue(25));
        }).toSet());

    var mergeStream2 = Rx.combineLatest2(
        mergeStream1, subDestMarker, (a, b) => a.followedBy(b).toSet());
    // return mergeStream2.map((event) => event.followedBy(_markers).toSet());
    // setState(() {
    //   _makingMarker = false;
    // });
    return mergeStream2;
  }

  // データをmarkerに変更する
  Marker _convertToMarker(
      QueryDocumentSnapshot user, Stream<DocumentSnapshot> mainGroupSnapshot) {
    String id = user.get("userId");
    GeoPoint position = user.get("location");
    // double color = id == _myId
    //     ? 0
    //     : _isMatchSubgroups(user)
    //         ? 180
    //         : 205;
    BitmapDescriptor icon = id == _myId
        ? redIcon
        : _isMatchSubgroups(user)
            ? lightBlueIcon
            : blueIcon;
    Stream<DocumentSnapshot<Object?>> arrivalTimes =
        mainGroupSnapshot.map((event) => event.get("arrivalTimes"));
    // get arrivaltime[userId]
    return Marker(
      markerId: MarkerId(id),
      position: LatLng(position.latitude, position.longitude),
      infoWindow: InfoWindow(
          title: user.get("name"),
          snippet:
              "到着予定時刻：${arrivalTimes.map((event) => event.get(id)) ?? "未定"}"),
      // icon: BitmapDescriptor.defaultMarkerWithHue(color));
      icon: icon,
    );
  }

  Future<bool> get isGranted async {
    final status = await permission.Permission.location.status;
    switch (status) {
      case permission.PermissionStatus.granted:
      case permission.PermissionStatus.limited:
        return true;
      case permission.PermissionStatus.denied:
      case permission.PermissionStatus.permanentlyDenied:
      case permission.PermissionStatus.restricted:
        return false;
      default:
        return false;
    }
  }

  Future<bool> get isAlwaysGranted {
    return permission.Permission.locationAlways.isGranted;
  }

  Future<LocationPermissionStatus> whileRequest() async {
    final status = await permission.Permission.location.request();
    switch (status) {
      case permission.PermissionStatus.granted:
        return LocationPermissionStatus.granted;
      case permission.PermissionStatus.denied:
        return LocationPermissionStatus.denied;
      case permission.PermissionStatus.limited:
      case permission.PermissionStatus.permanentlyDenied:
        return LocationPermissionStatus.permanentlyDenied;
      case permission.PermissionStatus.restricted:
        return LocationPermissionStatus.restricted;
      default:
        return LocationPermissionStatus.denied;
    }
  }

  Future<LocationPermissionStatus> alwaysRequest() async {
    if (!kIsWeb) {
      final status = await permission.Permission.locationAlways.request();
      switch (status) {
        case permission.PermissionStatus.granted:
          return LocationPermissionStatus.granted;
        default:
          return LocationPermissionStatus.denied;
      }
    } else {
      return LocationPermissionStatus.denied;
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
          body: _looding
              ? const Center(
                  child: CircularProgressIndicator(
                  color: Colors.blue,
                ))
              : StreamBuilder(
                  stream: _makeMarkers(),
                  builder: (BuildContext context,
                      AsyncSnapshot<Set<Marker>> markers) {
                    return GoogleMap(
                      onMapCreated: (controller) {
                        _onMapCreated(controller);
                      },
                      initialCameraPosition: CameraPosition(
                        target:
                            LatLng(_myPosition.latitude, _myPosition.longitude),
                        zoom: 16.0,
                      ),
                      markers: markers.data!,
                    );
                  }),
          floatingActionButtonLocation: FloatingActionButtonLocation.miniEndTop,
          floatingActionButton: Stack(children: [
            Align(
                alignment: Alignment.topRight,
                child: Container(
                    margin: const EdgeInsets.only(top: 20),
                    child: _notificationCount > 0
                        ? Badge.count(
                            largeSize: 22,
                            count: _notificationCount,
                            textStyle: const TextStyle(fontSize: 14),
                            padding: const EdgeInsets.only(left: 4, right: 4),
                            child: FloatingActionButton(
                              heroTag: "info",
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => InfoPage(
                                              user: widget.user,
                                            )));
                              },
                              tooltip: '通知',
                              child: const Icon(Icons.notifications),
                            ))
                        : FloatingActionButton(
                            heroTag: "info",
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => InfoPage(
                                            user: widget.user,
                                          )));
                            },
                            tooltip: '通知',
                            child: const Icon(Icons.notifications),
                          ))),
            _myGroup != ""
                ? Align(
                    alignment: Alignment.bottomLeft,
                    child: Column(children: [
                      FloatingActionButton(
                        heroTag: "current",
                        onPressed: () {
                          showCurrentLocation();
                        },
                        tooltip: '現在地',
                        child: const Icon(Icons.my_location),
                      ),
                      SizedBox(height: 8),
                      FloatingActionButton(
                        heroTag: "group",
                        onPressed: () {
                          showGroupLocation();
                        },
                        tooltip: 'グループ',
                        child: const Icon(Icons.group),
                      )
                    ]))
                : Container(),
          ])),
    );
  }
}

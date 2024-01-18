import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'add_user.dart';
import 'edit_group.dart';

class SubGroupPage extends StatefulWidget {
  final String? groupId;
  final User? user;
  const SubGroupPage({Key? key, this.user, this.groupId}) : super(key: key);

  @override
  _SubGroupPageState createState() => _SubGroupPageState();
}

class _SubGroupPageState extends State<SubGroupPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  Map? user;
  Map? group;
  List<Map?>? groupUsers = [];
  Set<Marker> markers = {};
  final Completer<GoogleMapController> _controller = Completer();

  Future<Map?> getUser() async {
    DocumentSnapshot user =
        await firestore.collection('USERS').doc(widget.user?.uid).get();
    if (!user.exists) {
      return null;
    }
    return user.data() as Map;
  }

  Future<Map?> getGroup(String gid) async {
    DocumentSnapshot group =
        await firestore.collection("GROUPS").doc(gid).get();
    if (!group.exists) {
      return null;
    }
    return group.data() as Map;
  }

  Future<List<Map?>?> getGroupUsers(String gid) async {
    QuerySnapshot users = await firestore
        .collection("USERS")
        .where("currentSubgroupId", arrayContains: gid)
        .get();
    if (users.docs.isEmpty) {
      return null;
    }
    return users.docs.map((e) => e.data() as Map).toList();
  }

  Future<void> reload(String gid) async {
    getUser().then((value) {
      setState(() {
        user = value;
      });
      if (user!["currentGroupId"] == null || user!["currentGroupId"] == "") {
        return;
      }
      getGroup(gid).then((value) {
        setState(() {
          group = value;
        });
        getGroupUsers(gid).then((value) {
          setState(() {
            groupUsers = value;
          });
        });
        showGroupLocation();
      });
    });
  }

  Future<void> showGroupLocation() async {
    final GoogleMapController controller = await _controller.future;
    GeoPoint geoloc = group!["destination"] as GeoPoint;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(geoloc.latitude, geoloc.longitude),
        zoom: 16,
      ),
    ));

    setState(() {
      markers.add(Marker(
          markerId: const MarkerId("destination"),
          position: LatLng(geoloc.latitude, geoloc.longitude),
          infoWindow: const InfoWindow(title: "集合場所")));
    });
  }

  String getArrivalTime() {
    return "予想集合時刻";
  }

  @override
  void initState() {
    super.initState();
    reload(widget.groupId!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        body: group != null
            ? Padding(
                padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.arrow_back, size: 32)),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Wrap(
                                direction: Axis.vertical,
                                spacing: 8,
                                children: <Widget>[
                                  Text(group?["name"],
                                      style: const TextStyle(fontSize: 32)),
                                  Text(getArrivalTime(),
                                      style: const TextStyle(fontSize: 24)),
                                ]),
                            user!["userId"] == group!["host"]
                                ? Row(
                                    children: [
                                      IconButton(
                                          onPressed: () {
                                            Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                        builder: (context) =>
                                                            EditGroupPage(
                                                                user: user,
                                                                group: group,
                                                                type:
                                                                    "SubgroupEdit")))
                                                .then((value) =>
                                                    reload(group!["groupId"]!));
                                          },
                                          icon: const Icon(
                                            Icons.edit,
                                            size: 32,
                                          )),
                                      const SizedBox(width: 8),
                                      IconButton(
                                          onPressed: () {
                                            showDialog(
                                                context: context,
                                                builder:
                                                    (BuildContext context) {
                                                  return AlertDialog(
                                                    title: const Text("確認"),
                                                    content: const Text(
                                                        "集合を完了にしますか？"),
                                                    actions: [
                                                      TextButton(
                                                          onPressed: () {
                                                            Navigator.pop(
                                                                context);
                                                          },
                                                          child: const Text(
                                                              "いいえ")),
                                                      TextButton(
                                                          onPressed: () {
                                                            firestore
                                                                .collection(
                                                                    "GROUPS")
                                                                .doc(group![
                                                                    "groupId"])
                                                                .delete();
                                                            firestore
                                                                .collection(
                                                                    "USERS")
                                                                .doc(widget
                                                                    .user?.uid)
                                                                .update({
                                                              "currentSubgroupId":
                                                                  FieldValue
                                                                      .arrayRemove([
                                                                group![
                                                                    "groupId"]
                                                              ])
                                                            });
                                                            Navigator.pop(
                                                                context);
                                                          },
                                                          child:
                                                              const Text("はい"))
                                                    ],
                                                  );
                                                });
                                          },
                                          icon: const Icon(
                                            Icons.check,
                                            size: 32,
                                          )),
                                    ],
                                  )
                                : Container(),
                          ]),
                      const SizedBox(height: 10),
                      SizedBox(
                          height: 200,
                          child: GoogleMap(
                            initialCameraPosition: const CameraPosition(
                              target: LatLng(35.681236, 139.767125),
                              zoom: 15,
                            ),
                            markers: markers,
                            onMapCreated: (GoogleMapController controller) {
                              _controller.complete(controller);
                            },
                            myLocationEnabled: true,
                          )),
                      const SizedBox(height: 20),
                      // user list
                      groupUsers!.isNotEmpty
                          ? LimitedBox(
                              maxHeight: 125,
                              child: MediaQuery.removePadding(
                                  context: context,
                                  removeTop: true,
                                  child: Scrollbar(
                                      child: ListView.builder(
                                          itemCount: groupUsers!.length,
                                          itemBuilder: (BuildContext context,
                                              int index) {
                                            return ListTile(
                                                leading: Icon(Icons.person,
                                                    color:
                                                        groupUsers![index]!["userId"] ==
                                                                group!["host"]
                                                            ? Colors.red
                                                            : Colors.black),
                                                title: Text(
                                                    groupUsers![index]!["name"],
                                                    style: TextStyle(
                                                        color: groupUsers![index]!["userId"] ==
                                                                group!["host"]
                                                            ? Colors.red
                                                            : Colors.black)),
                                                onTap: () {},
                                                trailing: (user!["userId"] == group!["host"] ||
                                                            user!["userId"] ==
                                                                groupUsers![index]![
                                                                    "userId"]) &&
                                                        (groupUsers![index]!["userId"] !=
                                                            group!["host"])
                                                    ? PopupMenuButton(
                                                        tooltip: '',
                                                        shape:
                                                            const RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.all(
                                                            Radius.circular(
                                                                20.0),
                                                          ),
                                                        ),
                                                        itemBuilder:
                                                            (BuildContext
                                                                    context) =>
                                                                <PopupMenuEntry>[
                                                          const PopupMenuItem(
                                                              value: "delete",
                                                              child:
                                                                  Text("削除")),
                                                        ],
                                                        child: const CircleAvatar(
                                                            backgroundColor:
                                                                Color.fromRGBO(
                                                                    0, 0, 0, 0),
                                                            child: Icon(Icons
                                                                .more_vert)),
                                                        onSelected: (value) {
                                                          if (value ==
                                                              "delete") {
                                                            showDialog(
                                                                context:
                                                                    context,
                                                                builder:
                                                                    (BuildContext
                                                                        context) {
                                                                  return AlertDialog(
                                                                    title:
                                                                        const Text(
                                                                            "確認"),
                                                                    content: Text(
                                                                        "ユーザー「${groupUsers![index]!['name']}」を削除しますか？"),
                                                                    actions: [
                                                                      TextButton(
                                                                          onPressed:
                                                                              () {
                                                                            Navigator.pop(context);
                                                                          },
                                                                          child:
                                                                              const Text("いいえ")),
                                                                      TextButton(
                                                                          onPressed:
                                                                              () {
                                                                            firestore.collection("USERS").doc(groupUsers![index]!["userId"]).update({
                                                                              "currentSubgroupId": FieldValue.arrayRemove([
                                                                                group!["groupId"]
                                                                              ])
                                                                            });
                                                                            setState(() {
                                                                              groupUsers!.removeAt(index);
                                                                            });
                                                                            Navigator.pop(context);
                                                                          },
                                                                          child:
                                                                              const Text("はい"))
                                                                    ],
                                                                  );
                                                                });
                                                          }
                                                        },
                                                      )
                                                    : null);
                                          }))))
                          : Container(),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            fixedSize: const Size.fromWidth(double.maxFinite),
                          ),
                          onPressed: user!["userId"] != group!["host"]
                              ? null
                              : () {
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (context) => AddUserPage(
                                              user: user, group: group))).then(
                                      (value) => reload(group!["groupId"]!));
                                },
                          child: const Text("ユーザーを追加")),
                    ]))
            : Container());
  }
}

import 'dart:async';
import 'package:comehere_dev/add_user.dart';
import 'package:comehere_dev/sub_group.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'edit_group.dart';

class GroupPage extends StatefulWidget {
  final User? user;
  const GroupPage({Key? key, this.user}) : super(key: key);

  @override
  _GroupPageState createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  String? temp;
  User? currentUser;
  Map? user;
  Map? group;
  String? groupId = "";
  List<Map?>? subGroups = [];
  List<Map?>? groupUsers = [];
  Set<Marker> markers = {};
  final Completer<GoogleMapController> _controller = Completer();
  final _groupIdController = TextEditingController();

  Future<Map?> getUser() async {
    DocumentSnapshot user =
        await firestore.collection('USERS').doc(currentUser!.uid).get();
    if (!user.exists) {
      return null;
    }
    return user.data() as Map;
  }

  // get user from firestore
  Future<Map?> getGroup() async {
    DocumentSnapshot group =
        await firestore.collection("GROUPS").doc(user!["currentGroupId"]).get();
    if (!group.exists) {
      return null;
    }
    return group.data() as Map;
  }

  Future<List<Map?>?> getGroupUsers() async {
    QuerySnapshot users = await firestore
        .collection("USERS")
        .where("currentGroupId", isEqualTo: user!["currentGroupId"])
        .get();
    if (users.docs.isEmpty) {
      return null;
    }
    return users.docs.map((e) => e.data() as Map).toList();
  }

  Future<List<Map?>?> getSubGroups() async {
    QuerySnapshot subGroups = await firestore
        .collection("GROUPS")
        .where("parentGroupId", isEqualTo: group!["groupId"])
        .get();
    if (subGroups.docs.isEmpty) {
      return [];
    }
    return subGroups.docs.map((e) => e.data() as Map).toList();
  }

  void changeMsg(text, duration) {
    setState(() {
      temp = text;
    });
    Future.delayed(Duration(milliseconds: duration), () {
      setState(() {
        temp = null;
      });
    });
  }

  Future<void> reload() async {
    getUser().then((value) {
      setState(() {
        user = value;
      });
      if (user!["currentGroupId"] == null || user!["currentGroupId"] == "") {
        return;
      }
      getGroup().then((value) {
        setState(() {
          group = value;
        });
        getGroupUsers().then((value) {
          setState(() {
            groupUsers = value;
          });
        });
        getSubGroups().then((value) {
          setState(() {
            subGroups = value;
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
    if (group!["arrivalTimes"] == {}) {
      return "集合時刻未定";
    }
    /*
    ex: arrivalTimes = {
      uid: DateTime
      ...
    }
    show slowest arrival time
    */
    Map<String, dynamic> arrivalTimes = group!["arrivalTimes"];
    List<DateTime> arrivalTimeList = [];
    arrivalTimes.forEach((key, value) {
      arrivalTimeList.add(value.toDate());
    });
    arrivalTimeList.sort((a, b) => a.compareTo(b));
    return "${arrivalTimeList.last.hour.toString().padLeft(2, '0')}:${arrivalTimeList.last.minute.toString().padLeft(2, '0')}完了予定";
  }

  @override
  void initState() {
    super.initState();
    currentUser = widget.user;
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        body: group != null
            ? Padding(
                padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
                child: Column(children: [
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
                                                            group: group)))
                                            .then((value) => reload());
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
                                            builder: (BuildContext context) {
                                              return AlertDialog(
                                                title: const Text("確認"),
                                                content:
                                                    const Text("集合を完了にしますか？"),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () {
                                                        Navigator.pop(context);
                                                      },
                                                      child: const Text("いいえ")),
                                                  TextButton(
                                                      onPressed: () {
                                                        firestore
                                                            .collection(
                                                                "GROUPS")
                                                            .doc(group![
                                                                "groupId"])
                                                            .delete();
                                                        WriteBatch batch =
                                                            firestore.batch();
                                                        for (var element
                                                            in groupUsers!) {
                                                          batch.update(
                                                              firestore
                                                                  .collection(
                                                                      "USERS")
                                                                  .doc(element![
                                                                      "userId"]),
                                                              {
                                                                "currentGroupId":
                                                                    FieldValue
                                                                        .arrayRemove([
                                                                  group![
                                                                      "groupId"]
                                                                ])
                                                              });
                                                        }
                                                        batch.commit();
                                                        firestore
                                                            .collection("USERS")
                                                            .doc(currentUser!
                                                                .uid)
                                                            .update({
                                                          "currentGroupId": ""
                                                        });
                                                        Navigator.pop(context);
                                                      },
                                                      child: const Text("はい"))
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
                          maxHeight: 100,
                          child: MediaQuery.removePadding(
                              context: context,
                              removeTop: true,
                              child: Scrollbar(
                                  child: ListView.builder(
                                      itemCount: groupUsers!.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
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
                                                    color:
                                                        groupUsers![index]!["userId"] ==
                                                                group!["host"]
                                                            ? Colors.red
                                                            : Colors.black)),
                                            onTap: () {},
                                            trailing:
                                                (user!["userId"] == group!["host"] ||
                                                            user!["userId"] ==
                                                                groupUsers![index]![
                                                                    "userId"]) &&
                                                        (groupUsers![index]![
                                                                "userId"] !=
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
                                                                              "currentGroupId": null
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
                                              user: user, group: group)))
                                  .then((value) => reload());
                            },
                      child: const Text("ユーザーを招待")),
                  const SizedBox(height: 20),
                  subGroups!.isNotEmpty
                      ? LimitedBox(
                          maxHeight: 100,
                          child: MediaQuery.removePadding(
                              context: context,
                              removeTop: true,
                              child: Scrollbar(
                                  child: ListView.builder(
                                      itemCount: subGroups!.length,
                                      itemBuilder:
                                          (BuildContext context, int index) {
                                        return ListTile(
                                            leading: const Icon(Icons.group),
                                            title: Text(
                                                subGroups![index]!["name"]),
                                            onTap: () {
                                              Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                          builder: (context) =>
                                                              SubGroupPage(
                                                                groupId: subGroups![
                                                                        index]![
                                                                    "groupId"],
                                                              )))
                                                  .then((value) => reload());
                                            },
                                            trailing:
                                                group!["host"] ==
                                                            user!["userId"] ||
                                                        subGroups![index]![
                                                                "host"] ==
                                                            user!["userId"]
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
                                                                        "サブグループ「${subGroups![index]!['name']}」を削除しますか？"),
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
                                                                            List<Map?>?
                                                                                subGroupUsers =
                                                                                [];
                                                                            subGroupUsers =
                                                                                groupUsers!.where((element) => element!["currentSubgroupId"].contains(subGroups![index]!["groupId"])).toList();
                                                                            firestore.collection("GROUPS").doc(subGroups![index]!["groupId"]).delete();
                                                                            WriteBatch
                                                                                batch =
                                                                                firestore.batch();
                                                                            for (var element
                                                                                in subGroupUsers) {
                                                                              batch.update(firestore.collection("USERS").doc(element!["userId"]), {
                                                                                "currentSubgroupId": FieldValue.arrayRemove([
                                                                                  subGroups![index]!["groupId"]
                                                                                ])
                                                                              });
                                                                            }
                                                                            batch.commit();
                                                                            setState(() {
                                                                              subGroups!.removeAt(index);
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
                      onPressed: () {
                        Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => EditGroupPage(
                                        user: user,
                                        group: group,
                                        type: "SubgroupCreation")))
                            .then((value) => reload());
                      },
                      child: const Text("サブグループを追加"))
                ]))
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text("グループに参加していません"),
                    const SizedBox(height: 20),
                    ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      EditGroupPage(user: user))).then(
                              (value) => Future.delayed(
                                  const Duration(milliseconds: 500),
                                  () => reload()));
                        },
                        child: const Text("グループを作成")),
                    const SizedBox(height: 20),
                    SizedBox(
                        width: 300,
                        child: TextField(
                          controller: _groupIdController,
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: "グループID"),
                          onChanged: (value) {
                            setState(() {
                              groupId = value;
                            });
                          },
                        )),
                    const SizedBox(height: 20),
                    ElevatedButton(
                        onPressed: () async {
                          if (_groupIdController.text == "") {
                            return;
                          }
                          Map? groupData = (await firestore
                                  .collection("GROUPS")
                                  .doc(_groupIdController.text)
                                  .get())
                              .data();
                          if (groupData == null) {
                            changeMsg("グループが見つかりませんでした", 3000);
                            return;
                          }
                          String newDoc =
                              firestore.collection("INVITES").doc().id;
                          await firestore
                              .collection("INVITES")
                              .doc(newDoc)
                              .set({
                            "createdAt": FieldValue.serverTimestamp(),
                            "toId": groupData["host"],
                            "fromId": currentUser!.uid,
                            "groupId": _groupIdController.text,
                            "inviteId": newDoc,
                            "type": "Application",
                          });
                          changeMsg("参加申請を送信しました", 2000);
                        },
                        child: Text(temp ?? "参加申請を送信"))
                  ],
                ),
              ));
  }
}

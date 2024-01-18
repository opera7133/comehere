import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InfoPage extends StatefulWidget {
  final User? user;
  const InfoPage({Key? key, this.user}) : super(key: key);

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  User? user;

  @override
  void initState() {
    super.initState();
    user = widget.user;
    _getNotifications();
  }

  Future<List<Object?>?> _getNotifications() async {
    QuerySnapshot snapshot = await firestore
        .collection("INVITES")
        .where("toId", isEqualTo: user!.uid)
        .orderBy("createdAt", descending: true)
        .get();
    return snapshot.docs.map((e) => e.data()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("通知"),
        ),
        body: Column(children: [
          FutureBuilder(
            future: _getNotifications(),
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.data.isEmpty) {
                  return const Center(
                    child: Text("通知はありません"),
                  );
                }
                Map notification = snapshot.data[0];
                return Expanded(
                    child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: snapshot.data.length,
                  itemBuilder: (BuildContext context, int index) {
                    return ListTile(
                      title: Text(
                          notification["type"] == "Invite" ? "招待" : "参加申請"),
                      subtitle: Text(
                          "${(notification["createdAt"] as Timestamp).toDate()}\n${notification["message"]}"),
                      trailing: PopupMenuButton(
                        itemBuilder: (BuildContext context) {
                          return [
                            const PopupMenuItem(
                              value: "check",
                              child: Text("承諾"),
                            ),
                            const PopupMenuItem(
                              value: "delete",
                              child: Text("削除"),
                            )
                          ];
                        },
                        onSelected: (String value) async {
                          if (value == "delete") {
                            await firestore
                                .collection("INVITES")
                                .doc(notification["id"])
                                .delete();
                            setState(() {
                              snapshot.data.removeAt(index);
                            });
                          }
                          if (value == "check") {
                            if (notification["type"] == "Invite") {
                              if (notification["groupType"] == "Subgroup") {
                                await firestore
                                    .collection("USERS")
                                    .doc(user!.uid)
                                    .update({
                                  "currentSubgroupId": FieldValue.arrayUnion(
                                      [notification["groupId"]])
                                });
                              } else {
                                await firestore
                                    .collection("USERS")
                                    .doc(user!.uid)
                                    .update({
                                  "currentGroupId": notification["groupId"]
                                });
                              }
                              await firestore
                                  .collection("INVITES")
                                  .doc(notification["inviteId"])
                                  .delete();
                            } else {
                              if (notification["groupType"] == "Subgroup") {
                                await firestore
                                    .collection("USERS")
                                    .doc(notification["fromId"])
                                    .update({
                                  "currentSubgroupId": FieldValue.arrayUnion(
                                      [notification["groupId"]])
                                });
                              } else {
                                await firestore
                                    .collection("USERS")
                                    .doc(notification["fromId"])
                                    .update({
                                  "currentGroupId": notification["groupId"]
                                });
                              }
                              await firestore
                                  .collection("GROUPS")
                                  .doc(notification["groupId"])
                                  .update({
                                "members": FieldValue.arrayUnion(
                                    [notification["fromId"]])
                              });
                              await firestore
                                  .collection("INVITES")
                                  .doc(notification["inviteId"])
                                  .delete();
                              setState(() {
                                snapshot.data.removeAt(index);
                              });
                            }
                          }
                        },
                      ),
                    );
                  },
                  separatorBuilder: (BuildContext context, int index) {
                    return const Divider();
                  },
                ));
              }
              return const Center(
                child: CircularProgressIndicator(),
              );
            },
          )
        ]));
  }
}

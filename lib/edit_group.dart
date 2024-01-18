import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class EditGroupPage extends StatefulWidget {
  final Map? group;
  final Map? user;
  final String? type;
  const EditGroupPage({Key? key, this.user, this.group, this.type})
      : super(key: key);

  @override
  _EditGroupPageState createState() => _EditGroupPageState();
}

class _EditGroupPageState extends State<EditGroupPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  Map? group;
  Map? user;
  String? type;
  bool isSubgroup = false;
  final formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  final _groupAddressController = TextEditingController();
  Set<Marker> markers = {
    const Marker(
        markerId: MarkerId("destination"),
        position: LatLng(35.681236, 139.767125))
  };
  final Completer<GoogleMapController> _controller = Completer();

  Future<void> onMapCreated() async {
    if (group == null) {
      return;
    }
    final GoogleMapController controller = await _controller.future;
    if (group!["address"] != null && group!["address"] != "") {
      getLocationByAddress(group!["address"]).then((value) {
        if (value != null) {
          setState(() {
            markers = {
              Marker(
                markerId: const MarkerId("destination"),
                position: LatLng(value.lat, value.lng),
              )
            };
            controller
                .animateCamera(CameraUpdate.newCameraPosition(
              CameraPosition(
                target: LatLng(value.lat, value.lng),
                zoom: 16,
              ),
            ))
                .then(
              (value) {
                Future.delayed(const Duration(microseconds: 10), () {
                  setState(() {
                    _groupAddressController.text = group!['address'] ?? '';
                  });
                });
              },
            );
          });
        }
      });
    } else {
      GeoPoint geoloc = group!["destination"] as GeoPoint;
      setState(() {
        markers = {
          Marker(
            markerId: const MarkerId("destination"),
            position: LatLng(geoloc.latitude, geoloc.longitude),
          )
        };
        controller.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(geoloc.latitude, geoloc.longitude),
            zoom: 16,
          ),
        ));
      });
    }
  }

  void onCameraMove(CameraPosition position) {
    _groupAddressController.text = "";
    setState(() {
      markers = {
        Marker(
          markerId: MarkerId(position.target.toString()),
          position: position.target,
        )
      };
    });
  }

  Future<void> updateGroup() async {
    if (group != null) {
      if (isSubgroup) {
        if (type == "SubgroupCreation") {
          String newDoc = firestore.collection("GROUPS").doc().id;
          await firestore.collection('GROUPS').doc(newDoc).set({
            'name': _groupNameController.text,
            'address': _groupAddressController.text,
            'destination': GeoPoint(markers.first.position.latitude,
                markers.first.position.longitude),
            'parentGroupId': group!['groupId'],
            'host': user!['userId'],
            'groupId': newDoc,
            'type': "Subgroup"
          });
          await firestore.collection('USERS').doc(user!["userId"]).update({
            'currentSubgroupId': FieldValue.arrayUnion([newDoc])
          });
        } else if (type == "SubgroupEdit") {
          await firestore.collection('GROUPS').doc(group!['groupId']).update({
            'name': _groupNameController.text,
            'address': _groupAddressController.text,
            'destination': GeoPoint(markers.first.position.latitude,
                markers.first.position.longitude),
          });
        }
      } else {
        await firestore.collection('GROUPS').doc(group!['groupId']).update({
          'name': _groupNameController.text,
          'address': _groupAddressController.text,
          'destination': GeoPoint(markers.first.position.latitude,
              markers.first.position.longitude),
        });
      }
    } else {
      String newDoc = firestore.collection("GROUPS").doc().id;
      await firestore.collection('GROUPS').doc(newDoc).set({
        'name': _groupNameController.text,
        'address': _groupAddressController.text,
        'destination': GeoPoint(
            markers.first.position.latitude, markers.first.position.longitude),
        'parentGroupId': null,
        'host': user!['userId'],
        'type': "Group",
        'groupId': newDoc,
      });
      await firestore.collection('USERS').doc(user!['userId']).update({
        'currentGroupId': newDoc,
      });
    }
  }

  Future<Location?> getLocationByAddress([String? address]) async {
    String address0 = address ?? _groupAddressController.text;
    final response = await http.get(Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?address=$address0&key='));
    if (response.statusCode == 200) {
      final geocodingResponse =
          GeocodingResponse.fromJson(jsonDecode(response.body));
      final location = geocodingResponse.results[0].geometry.location;
      return location;
    } else {
      return null;
    }
  }

  String getTitleText() {
    if (type == "SubgroupCreation") {
      return "サブグループ作成";
    } else if (type == "SubgroupEdit") {
      return "サブグループ編集";
    } else if (type == "GroupCreation" || group == null) {
      return "グループ作成";
    } else if (type == "GroupEdit" || group != null) {
      return "グループ編集";
    } else {
      return "グループ作成";
    }
  }

  @override
  void initState() {
    super.initState();
    group = widget.group;
    user = widget.user;
    type = widget.type;
    if (group != null) {
      _groupNameController.text = group!['name'];
      _groupAddressController.text = group!['address'] ?? '';
    }
    if (type.toString().contains("Subgroup")) {
      setState(() {
        isSubgroup = true;
        if (type == "SubgroupCreation") {
          _groupNameController.text = "";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Padding(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 36),
            child: Form(
              key: formKey,
              child: Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(getTitleText(),
                          style: const TextStyle(fontSize: 30)),
                    ]),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _groupNameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'グループ名',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'グループ名を入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _groupAddressController,
                  decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      labelText: '住所・建物・駅名',
                      suffixIcon: IconButton(
                          onPressed: () async {
                            final GoogleMapController controller =
                                await _controller.future;
                            getLocationByAddress().then((value) => {
                                  if (value != null)
                                    {
                                      setState(() {
                                        markers = {
                                          Marker(
                                            markerId:
                                                const MarkerId("destination"),
                                            position:
                                                LatLng(value.lat, value.lng),
                                          )
                                        };
                                        String temp =
                                            _groupAddressController.text;
                                        controller.animateCamera(
                                            CameraUpdate.newCameraPosition(
                                          CameraPosition(
                                            target:
                                                LatLng(value.lat, value.lng),
                                            zoom: 16,
                                          ),
                                        ));
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                        Future.delayed(
                                            const Duration(microseconds: 10),
                                            () {
                                          setState(() {
                                            _groupAddressController.text = temp;
                                          });
                                        });
                                      })
                                    }
                                });
                          },
                          icon: const Icon(Icons.search))),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 400,
                  child: GoogleMap(
                    mapType: MapType.normal,
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(35.681236, 139.767125),
                      zoom: 15,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      _controller.complete(controller);
                      onMapCreated();
                    },
                    markers: markers,
                    onCameraMove: onCameraMove,
                    onTap: (LatLng latLng) {
                      setState(() {
                        markers = {
                          Marker(
                            markerId: MarkerId(latLng.toString()),
                            position: latLng,
                          )
                        };
                      });
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text("キャンセル")),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              updateGroup();
                              Navigator.pop(context, {
                                'name': _groupNameController.text,
                                'address': _groupAddressController.text,
                                'destination': GeoPoint(
                                    markers.first.position.latitude,
                                    markers.first.position.longitude)
                              });
                            }
                          },
                          child: const Text("保存")),
                    ),
                  ],
                )
              ]),
            )));
  }
}

// create geocoding api response model
class GeocodingResponse {
  final List<GeocodingResult> results;

  GeocodingResponse({required this.results});

  factory GeocodingResponse.fromJson(Map<String, dynamic> json) {
    final results = json['results'] as List;
    return GeocodingResponse(
        results: results.map((e) => GeocodingResult.fromJson(e)).toList());
  }
}

class GeocodingResult {
  final Geometry geometry;

  GeocodingResult({required this.geometry});

  factory GeocodingResult.fromJson(Map<String, dynamic> json) {
    final geometry = Geometry.fromJson(json['geometry']);
    return GeocodingResult(geometry: geometry);
  }
}

class Geometry {
  final Location location;

  Geometry({required this.location});

  factory Geometry.fromJson(Map<String, dynamic> json) {
    final location = Location.fromJson(json['location']);
    return Geometry(location: location);
  }
}

class Location {
  final double lat;
  final double lng;

  Location({required this.lat, required this.lng});

  factory Location.fromJson(Map<String, dynamic> json) {
    final lat = json['lat'] as double;
    final lng = json['lng'] as double;
    return Location(lat: lat, lng: lng);
  }
}

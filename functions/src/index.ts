/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import type {GeoPoint} from "firebase-admin/firestore";
import {add} from "date-fns";
admin.initializeApp();

const firestore = admin.firestore();
const googleApiKey = process.env.GOOGLE_API_KEY;
exports.getArrivalTime = onRequest(
  {region: "asia-northeast1", memory: "512MiB"},
  async (req, res) => {
    logger.info("getArrivalTime");
    // get all groups
    const groups = await firestore.collection("GROUPS").get();
    let batch = firestore.batch();
    for (const group of groups.docs) {
      const groupData = group.data();
      const groupRef = firestore.collection("GROUPS").doc(group.id);
      const destination = groupData.destination as GeoPoint;
      let members;
      if (groupData.type === "Group") {
        members = await firestore
          .collection("USERS")
          .where("currentGroupId", "==", group.id)
          .get();
      } else {
        members = await firestore
          .collection("USERS")
          .where("currentSubgroupId", "array-contains", group.id)
          .get();
      }
      const arrivalTimes: {
        [key: string]: Date;
      } = {};
      const distances: {
        [key: string]: number;
      } = {};
      let count = 0;
      for (const member of members.docs) {
        const origin = member.data().location as GeoPoint;
        let url = "https://maps.googleapis.com/maps/api/distancematrix/json";
        url += `?origins=${origin.latitude},${origin.longitude}`;
        url += `&destinations=${destination.latitude},${destination.longitude}`;
        url += `&travelMode=TRANSIT&key=${googleApiKey}`;
        const response = await fetch(url);
        const json = await response.json();
        if (json && json.rows[0].elements[0]) {
          const dt = json.rows[0].elements[0];
          if (dt) {
            if (dt.distance && dt.duration) {
              if (dt.distance.value && dt.duration.value) {
                const arrivalTime = add(new Date(), {
                  seconds: Number(dt.duration.value),
                });
                const distance = Number(dt.distance.value);
                arrivalTimes[member.id] = arrivalTime;
                distances[member.id] = distance;
              }
            }
          }
        } else {
          logger.info("empty");
        }
      }
      if (count === 500) {
        await batch.commit();
        batch = firestore.batch();
        count = 0;
      }
      batch.update(groupRef, {
        arrivalTimes: arrivalTimes,
        distances: distances,
      });
      count++;
    }
    await batch.commit();
    res.send("ok");
    logger.info("getArrivalTime done");
  }
);

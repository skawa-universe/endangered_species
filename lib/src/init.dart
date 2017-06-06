import "dart:async";
import "dart:io";
import "package:http/http.dart" as http;
import "package:googleapis_auth/auth_io.dart" as auth;
import "package:googleapis/datastore/v1.dart" as ds;
import "package:entify/entify.dart";

// Change these to your local settings
const String credentialsPath = "datastoreCredentials.json";
final bool localDevelopment = !new File(credentialsPath).existsSync();
// Replace this with your own app id if you're using the Cloud Datastore,
// and not the emulator
const String appId = "species";

// Standard boilerplate code for getting a googleapis DatastoreApi object

Future<http.Client> getClient() async {
  if (localDevelopment) {
    print("local development, using no credentials");
    return new http.Client();
  }
  String credentials = await new File(credentialsPath).readAsString();
  return auth.clientViaServiceAccount(
      new auth.ServiceAccountCredentials.fromJson(credentials),
      [ds.DatastoreApi.DatastoreScope]);
}

Future<ds.DatastoreApi> getDatastoreApi() async {
  http.Client client = await getClient();
  if (localDevelopment) {
    print("local development, using datastore at localhost:8081\n");
    return new ds.DatastoreApi(client, rootUrl: "http://localhost:8081/");
  }
  print("Using Google Cloud Datastore\n");
  return new ds.DatastoreApi(client);
}

Future<DatastoreShell> getDatastoreShell() =>
    getDatastoreApi().then((api) => new DatastoreShell(api, appId));

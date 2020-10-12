import "dart:async";
import "dart:math" as math;
import "package:googleapis/datastore/v1.dart" as ds;
import "dart:convert" show json;
import "dart:io";
import "package:entify/entify.dart";

import "model.dart";
import "init.dart";

/// Fills the database with the
Future<Null> populate(List<String> args) async {
  Future<DatastoreShell> datastoreFuture = getDatastoreShell();
  File source = new File("endangered_species.json");
  String speciesJson = await source.readAsString();
  Map<String, dynamic> allSpecSpec = json.decode(speciesJson);
  List<String> fieldNames = List<String>.from(allSpecSpec["fields"]);
  int commonNameIndex = fieldNames.indexOf("Name");
  int sciNameIndex = fieldNames.indexOf("Scientific name");
  int statusIndex = fieldNames.indexOf("Status");
  int firstTaxon =
      math.max(math.max(commonNameIndex, sciNameIndex), statusIndex) + 1;
  List<Species> species = [];
  for (List rawValues in allSpecSpec["data"]) {
    List<String> values = List.from(rawValues);
    Species spec = new Species();
    spec.scientificName = values[sciNameIndex];
    spec.commonName = values[commonNameIndex];
    spec.status = values[statusIndex];
    int len = values.length;
    for (int i = firstTaxon; i < len; ++i) {
      String rank = fieldNames[i];
      String name = values[i];
      if (name != null) spec.taxonomy.add(new Taxon(rank, name));
    }
    species.add(spec);
  }
  DatastoreShell dsh = await datastoreFuture;
  try {
    await dsh
        .beginMutation()
        .insertAll(species.map((s) => s.toEntity()))
        .commit();
    print("${species.length} entities written");
  } on ds.DetailedApiRequestError catch (e) {
    print("DetailedApiRequestError: ${e.message}/${e.status}");
    print(json.encode(e.errors.map((e) => e.originalJson).toList()));
  } on DatastoreShellError catch (e) {
    print(e.runtimeType);
    print(e);
  }
}

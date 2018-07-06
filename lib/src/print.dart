import "package:entify/entify.dart";

import "model.dart";

void printSpeciesEntities(Iterable<Entity> entities, {bool projected: false}) {
  if (projected) {
    print(entities
        .map((e) => (e["taxonomyPaths"] ?? e["taxonomy"] as String)
            .replaceAll("/ ", "/"))
        .join("\n"));
  } else {
    printSpecies(entities.map((e) => new Species.fromEntity(e)));
  }
}

void printSpecies(Iterable<Species> species) {
  print(species.map((s) {
    return "${s.scientificName}, commonly known as ${s.commonName}"
        " is \"${s.status}\"\nTaxonomy: /${s.fullTaxonomyPath}\n";
  }).join("\n"));
}

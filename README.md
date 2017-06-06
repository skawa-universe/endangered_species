# endangered_species

An example project to query endangered species in various ways.

## Getting Started

Get the [datastore emulator](https://cloud.google.com/datastore/docs/tools/datastore-emulator)
and start a local datastore server:

```
gcloud beta emulators datastore start --project=species \
  --data-dir=<path to wherever you want to store the temporary files>
```

Populate the local repository:

    dart bin/species.dart populate

Make a query:

    dart bin/species.dart query Class:

    dart bin/species.dart query /Kingdom:Animalia/Phylum:Chordata/Class:Mammalia/Order:Carnivora

    dart bin/species.dart query /Kingdom:Animalia/Phylum:Chordata/Class:Mammalia/Order:Primates/**

    dart bin/species.dart query Order:Sirenia

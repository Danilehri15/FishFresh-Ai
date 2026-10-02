import 'package:flutter/material.dart';
import '../../core/theme.dart';

class CatalogView extends StatelessWidget {
  const CatalogView({super.key});

  final List<Map<String, String>> _speciesList = const [
    {
      "name": "Rohu",
      "urdu": "Rahu / Rohu Mach",
      "scientific": "Labeo rohita",
      "habitat": "Freshwater Major Carp (Indus River Basin)",
      "price": "Rs. 750 / kg",
      "desc": "Pakistan's most popular freshwater fish. Highly esteemed for its firm texture, rich protein, and delicate sweet flavor."
    },
    {
      "name": "Sufaid Rohu",
      "urdu": "Sufaid Rahu / Silver Carp",
      "scientific": "Hypophthalmichthys molitrix",
      "habitat": "Freshwater Aquaculture",
      "price": "Rs. 600 / kg",
      "desc": "Silvery major carp farmed across Punjab and Sindh aquaculture facilities. Lean meat, mild flavor."
    },
    {
      "name": "Dayya / Nile Tilapia",
      "urdu": "Dayya",
      "scientific": "Oreochromis niloticus",
      "habitat": "Freshwater Cichlid",
      "price": "Rs. 550 / kg",
      "desc": "Hardy, mild-flavored freshwater fish. Highly versatile for pan frying and quick curry preparation."
    },
    {
      "name": "Sulemani",
      "urdu": "Sulemani / Milkfish",
      "scientific": "Chanos chanos",
      "habitat": "Coastal Marine & Brackish",
      "price": "Rs. 850 / kg",
      "desc": "Prized coastal marine fish with shimmering silver scales and tender, omega-3 rich white meat."
    },
    {
      "name": "Poplet",
      "urdu": "Poplet / Silver Pomfret",
      "scientific": "Pampus argenteus",
      "habitat": "Premium Marine (Arabian Sea)",
      "price": "Rs. 1,600 / kg",
      "desc": "Pakistan's premium diamond-shaped marine fish. Tender buttery flesh, single central bone structure, and exquisite taste."
    },
    {
      "name": "Atlantic Salmon",
      "urdu": "Salmon",
      "scientific": "Salmo salar",
      "habitat": "Imported Cold-water Marine",
      "price": "Rs. 2,800 / kg",
      "desc": "World renowned for rich omega-3 oils, vibrant orange-pink flesh, and succulent flaky texture."
    },
    {
      "name": "European Anchovy",
      "urdu": "Hamsi",
      "scientific": "Engraulis encrasicolus",
      "habitat": "Marine Pelagic Forage",
      "price": "Rs. 450 / kg",
      "desc": "Small silver forage fish. Deep umami savory flavor, packed with calcium, traditionally pan fried crispy."
    },
    {
      "name": "Horse Mackerel",
      "urdu": "Istavrit",
      "scientific": "Trachurus trachurus",
      "habitat": "Pelagic Marine Fish",
      "price": "Rs. 650 / kg",
      "desc": "Fast pelagic fish with firm dark meat and distinct lateral scutes. Ideal for grilling, pan-searing, and smoking."
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Species Encyclopedia (8 Classes)'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _speciesList.length,
        itemBuilder: (context, idx) {
          final s = _speciesList[idx];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s['name']!,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                      ),
                      // Removed price badge
                    ],
                  ),
                  Text(
                    '${s['urdu']} • ${s['scientific']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700], fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Habitat: ${s['habitat']}',
                    style: TextStyle(fontSize: 11, color: Colors.teal[800], fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s['desc']!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[800], height: 1.3),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

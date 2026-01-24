import 'package:flutter/material.dart';

void main() {
  runApp(const ICaneApp());
}

class ICaneApp extends StatelessWidget {
  const ICaneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'I-cane App',
      home: MainPager(),
    );
  }
}

// MAIN PAGER

class MainPager extends StatefulWidget {
  const MainPager({super.key});

  @override
  State<MainPager> createState() => _MainPagerState();
}

class _MainPagerState extends State<MainPager> {
  int index = 0;

  final pages = const [
    DashboardScreen(),
    LocationScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        backgroundColor: Colors.green,
        selectedItemColor: Colors.yellow,
        unselectedItemColor: Colors.black,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: "Location"),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: "More"),
        ],
      ),
    );
  }
}

// DASHBOARD v1.2

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const cardColor = Color(0xFF63E0E3);

  Widget divider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      height: 6,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget underline(double width) {
    return Container(
      width: width,
      height: 1.2,
      color: Colors.black,
      margin: const EdgeInsets.only(top: 6),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Card(
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Status Summary",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text("I-Cane Battery"),
                        const Spacer(),
                        underline(60),
                        const Text(" %"),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: const [
                        Text("Connection Status"),
                        Spacer(),
                        Icon(Icons.circle, color: Colors.green, size: 14),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Text("Last Update time"),
                        const Spacer(),
                        underline(120),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            divider(),

            Card(
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Quick Location",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    const Text("📍 Last Known Address"),
                    underline(200),
                    const SizedBox(height: 14),
                    const Text("📍 Distance to the User"),
                    underline(160),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text("View Live Location"),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            divider(),

            const ExpandableSection(title: "Alert Log", scrollable: true),

            divider(),

            Card(
              color: cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  const ListTile(
                    title: Text("Quick Actions",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  grayButton("Call User"),
                  grayButton("Get Location"),
                  grayButton("Test Alert"),
                ],
              ),
            ),

            divider(),

            const ExpandableSection(title: "Recent Activity", scrollable: true),
          ],
        ),
      ),
    );
  }
}

// Expandable sections of the Dahsboard
class ExpandableSection extends StatefulWidget {
  final String title;
  final bool scrollable;

  const ExpandableSection({
    super.key,
    required this.title,
    this.scrollable = false,
  });

  @override
  State<ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<ExpandableSection> {
  bool open = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF63E0E3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Column(
        children: [
          ListTile(
            title: Text(widget.title,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: IconButton(
              icon: Icon(open ? Icons.expand_less : Icons.add),
              onPressed: () => setState(() => open = !open),
            ),
          ),
          if (open)
            SizedBox(
              height: widget.scrollable ? 160 : null,
              child: ListView.builder(
                itemCount: 6,
                itemBuilder: (_, i) => const ListTile(
                  leading: Icon(Icons.info),
                  title: Text("Entry"),
                  subtitle: Text("Details here"),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// MORE SCREEN (FULL SCREEN WITH LOGO AND APP NAME)
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Logo + App Name
              Center(
                child: Column(
                  children: [
                    // Replace this with your actual logo image if available
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          "Logo",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "I-Cane",
                      style:
                      TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // Group 1
              buildGroup(context, [
                ["User Profile", Icons.person],
                ["Caretaker Information", Icons.group]
              ]),

              // Group 2
              buildGroup(context, [
                ["Device Information", Icons.devices],
                ["Connection Settings", Icons.wifi]
              ]),

              // Group 3
              buildGroup(context, [
                ["Notification Settings", Icons.notifications],
                ["Display Settings", Icons.display_settings]
              ]),

              // Group 4
              buildGroup(context, [
                ["System Status", Icons.info_outline]
              ]),

              // Group 5
              buildGroup(context, [
                ["About I-Cane", Icons.info],
                ["Privacy & Data Use", Icons.privacy_tip],
                ["Help & Support", Icons.help_outline]
              ]),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Build a group of rows with optional icons
  Widget buildGroup(BuildContext context, List<List<dynamic>> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: items
            .map((item) => Column(
          children: [
            moreRow(context, item[0], item[1] as IconData),
            if (item != items.last)
              const Divider(height: 1, color: Colors.grey),
          ],
        ))
            .toList(),
      ),
    );
  }

  // Single row with icon on the left, text, and arrow on the right
  Widget moreRow(BuildContext context, String text, IconData iconData) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EmptyScreen(title: text)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(iconData, size: 24, color: Colors.black54),
                const SizedBox(width: 12),
                Text(text, style: const TextStyle(fontSize: 18)),
              ],
            ),
            const Icon(Icons.arrow_forward_ios, size: 18),
          ],
        ),
      ),
    );
  }
}


//SCREENS FOR THE ABOUT SECTION

class EmptyScreen extends StatelessWidget {
  final String title;

  const EmptyScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text("Empty Page")),
    );
  }
}

// Location SECTION

class LocationScreen extends StatelessWidget {
  const LocationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text("Location Screen (Empty)")),
    );
  }
}

/* ===========================
   SHARED BUTTON
=========================== */
Widget grayButton(String text) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    width: double.infinity,
    height: 40,
    child: ElevatedButton(
      onPressed: () {},
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(text),
    ),
  );
}

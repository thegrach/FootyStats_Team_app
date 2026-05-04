import 'package:flutter/material.dart';
import '../globals.dart';
import '../services/storage_service.dart';
import 'recording_screen.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _addCategory() {
    final TextEditingController _controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Category'),
        content: TextField(
          controller: _controller,
          decoration: InputDecoration(hintText: 'Enter category name'),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newCategory = _controller.text.trim();
              if (newCategory.isNotEmpty && !statCategories.contains(newCategory)) {
                setState(() {
                  statCategories.add(newCategory);
                });
                StorageService.saveCategories(statCategories);
                
                // Tell the recording screen to update
                final recordingState = recordingScreenKey.currentState as RecordingScreenState?;
                recordingState?.refreshCategories();
              }
              Navigator.pop(context);
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  void _deleteCategory(String category) {
    // Check if category has any recorded stats in the current match
    final hasStats = eventLog.any((event) => event.category == category);

    if (hasStats) {
      // Option C: Prevent deletion
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot delete: "$category" has recorded stats in the current match.'),
          backgroundColor: Colors.red,
        ),
      );
    } else {
      // Proceed with deletion
      setState(() {
        statCategories.remove(category);
      });
      StorageService.saveCategories(statCategories);
      
      final recordingState = recordingScreenKey.currentState as RecordingScreenState?;
      recordingState?.refreshCategories();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category "$category" deleted.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings (Customizer)'),
      ),
      body: ListView.builder(
        itemCount: statCategories.length,
        itemBuilder: (context, index) {
          final category = statCategories[index];
          return ListTile(
            title: Text(category),
            trailing: IconButton(
              icon: Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteCategory(category),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        child: Icon(Icons.add),
        tooltip: 'Add Category',
      ),
    );
  }
}

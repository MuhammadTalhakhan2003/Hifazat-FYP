import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hifazat_app/api/models/incident.dart';

// Helper class to hold style data for a marker
class MarkerStyle {
  final IconData icon;
  final Color color;

  MarkerStyle({required this.icon, required this.color});
}

class IncidentMarker extends StatelessWidget {
  final Incident incident;
  final VoidCallback onTap;

  const IncidentMarker({
    super.key,
    required this.incident,
    required this.onTap,
  });

  // This function maps a category name to a specific style (icon and color)
  MarkerStyle _getMarkerStyleForCategory(String categoryName) {
    switch (categoryName.toLowerCase()) {
      case 'terrorism & extremism':
        return MarkerStyle(icon: FontAwesomeIcons.bomb, color: Colors.black);
      case 'violent crime & homicide':
        return MarkerStyle(icon: FontAwesomeIcons.gun, color: Colors.red.shade800);
      case 'kidnapping & abduction':
        return MarkerStyle(icon: FontAwesomeIcons.handcuffs, color: Colors.blueGrey.shade800);
      case 'organized crime & trafficking':
        return MarkerStyle(icon: FontAwesomeIcons.briefcase, color: Colors.brown.shade800);
      case 'theft & robbery':
        return MarkerStyle(icon: FontAwesomeIcons.mask, color: Colors.deepOrange.shade800);
      case 'scams & fraud':
        return MarkerStyle(icon: FontAwesomeIcons.userSecret, color: Colors.purple.shade800);
      case 'sexual violence & abuse':
        return MarkerStyle(icon: FontAwesomeIcons.userSlash, color: Colors.pink.shade800);
      case 'public order & governance offenses':
        return MarkerStyle(icon: FontAwesomeIcons.gavel, color: Colors.indigo.shade800);
      case 'accidents & disasters':
        return MarkerStyle(icon: FontAwesomeIcons.carBurst, color: Colors.green.shade800);
      case 'drug crimes':
        return MarkerStyle(icon: FontAwesomeIcons.pills, color: Colors.teal.shade800);
      default:
        return MarkerStyle(icon: FontAwesomeIcons.circleQuestion, color: Colors.grey.shade600);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get the specific style for this incident's category
    final style = _getMarkerStyleForCategory(incident.properties.categoryName);
    
    // Define the size of the marker
    const double markerSize = 48.0;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Bottom layer: The colored marker pin shape
          Icon(
            Icons.location_pin,
            color: style.color,
            size: markerSize,
            // shadows: [
            //   Shadow(
            //     blurRadius: 10.0,
            //     color: Colors.black.withOpacity(0.5),
            //     offset: const Offset(0, 4),
            //   ),
            // ],
          ),
          // Top layer: The category-specific icon
          Positioned(
            top: markerSize * 0.40, // Adjust this value to center the icon vertically
            child: FaIcon(
              style.icon,
              color: Colors.white,
              size: markerSize * 0.3, // Icon should be smaller than the pin
            ),
          ),
        ],
      ),
    );
  }
}
// Complete Catalogue of 30 Ethiopian Job Categories and 475 Job Titles
// Derived from jobtitle.txt for offline-first querying, autocomplete, and search filtering.

import 'package:flutter/material.dart';

class EthiopianCategoryData {
  final int id;
  final String name;
  final String slug;
  final String iconName;
  final List<String> titles;

  const EthiopianCategoryData({
    required this.id,
    required this.name,
    required this.slug,
    required this.iconName,
    required this.titles,
  });

  IconData get icon {
    switch (iconName) {
      case 'agriculture':
        return Icons.agriculture;
      case 'home':
        return Icons.home;
      case 'engineering':
        return Icons.engineering;
      case 'chair':
        return Icons.chair;
      case 'school':
        return Icons.school;
      case 'security':
        return Icons.security;
      case 'account_balance':
        return Icons.account_balance;
      case 'business_center':
        return Icons.business_center;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'campaign':
        return Icons.campaign;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'local_shipping':
        return Icons.local_shipping;
      case 'hotel':
        return Icons.hotel;
      case 'precision_manufacturing':
        return Icons.precision_manufacturing;
      case 'computer':
        return Icons.computer;
      case 'phone_in_talk':
        return Icons.phone_in_talk;
      case 'mic':
        return Icons.mic;
      case 'gavel':
        return Icons.gavel;
      case 'volunteer_activism':
        return Icons.volunteer_activism;
      case 'spa':
        return Icons.spa;
      case 'science':
        return Icons.science;
      case 'bolt':
        return Icons.bolt;
      case 'work':
        return Icons.work;
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'water_drop':
        return Icons.water_drop;
      case 'brush':
        return Icons.brush;
      case 'flight':
        return Icons.flight;
      case 'child_care':
        return Icons.child_care;
      case 'receipt_long':
        return Icons.receipt_long;
      case 'lightbulb':
        return Icons.lightbulb;
      default:
        return Icons.work_outline;
    }
  }
}

class EthiopianJobCatalogue {
  static const List<EthiopianCategoryData> categories = [
    EthiopianCategoryData(
      id: 1,
      name: 'Agriculture and Farming',
      slug: 'agriculture-and-farming',
      iconName: 'agriculture',
      titles: [
        'Farmer',
        'Agricultural Worker',
        'Farm Manager',
        'Agricultural Engineer',
        'Agronomist',
        'Horticulturist',
        'Irrigation Worker',
        'Tractor Operator',
        'Poultry Farmer',
        'Dairy Farmer',
        'Cattle Herder',
        'Beekeeper',
        'Veterinarian',
        'Animal Health Technician',
        'Fish Farmer',
        'Agricultural Extension Worker',
        'Greenhouse Worker',
        'Fruit Grower',
        'Vegetable Grower',
        'Farm Supervisor',
      ],
    ),
    EthiopianCategoryData(
      id: 2,
      name: 'Domestic and Household Jobs',
      slug: 'domestic-and-household-jobs',
      iconName: 'home',
      titles: [
        'Housekeeper',
        'Housemaid',
        'Domestic Worker',
        'Nanny',
        'Babysitter',
        'Cook',
        'Private Chef',
        'House Cleaner',
        'Laundry Worker',
        'Ironing Worker',
        'Gardener',
        'Caregiver',
        'Elderly Care Assistant',
        'Childcare Assistant',
        'House Manager',
      ],
    ),
    EthiopianCategoryData(
      id: 3,
      name: 'Construction and Engineering',
      slug: 'construction-and-engineering',
      iconName: 'engineering',
      titles: [
        'Civil Engineer',
        'Construction Engineer',
        'Site Engineer',
        'Construction Manager',
        'Site Supervisor',
        'Architect',
        'Quantity Surveyor',
        'Land Surveyor',
        'Surveying Technician',
        'Mason',
        'Bricklayer',
        'Carpenter',
        'Electrician',
        'Plumber',
        'Welder',
        'Painter',
        'Plasterer',
        'Tiler',
        'Roofer',
        'Steel Fixer',
        'Concrete Worker',
        'Road Construction Worker',
        'Heavy Equipment Operator',
        'Excavator Operator',
        'Building Inspector',
      ],
    ),
    EthiopianCategoryData(
      id: 4,
      name: 'Furniture and Woodwork',
      slug: 'furniture-and-woodwork',
      iconName: 'chair',
      titles: [
        'Furniture Maker',
        'Furniture Designer',
        'Carpenter',
        'Cabinet Maker',
        'Furniture Assembler',
        'Upholsterer',
        'Woodworker',
        'Furniture Polisher',
        'Furniture Repairer',
        'Machine Woodworker',
      ],
    ),
    EthiopianCategoryData(
      id: 5,
      name: 'Education and Teaching',
      slug: 'education-and-teaching',
      iconName: 'school',
      titles: [
        'Kindergarten Teacher',
        'Primary School Teacher',
        'Secondary School Teacher',
        'University Lecturer',
        'University Professor',
        'Tutor',
        'Private Teacher',
        'English Teacher',
        'Mathematics Teacher',
        'Science Teacher',
        'Computer Teacher',
        'Special Needs Teacher',
        'School Principal',
        'Academic Coordinator',
        'School Administrator',
        'TVET Instructor',
        'Vocational Trainer',
        'Teaching Assistant',
        'Librarian',
        'Education Officer',
      ],
    ),
    EthiopianCategoryData(
      id: 6,
      name: 'Security and Protection',
      slug: 'security-and-protection',
      iconName: 'security',
      titles: [
        'Security Guard',
        'Night Guard',
        'Private Security Officer',
        'Security Supervisor',
        'Bodyguard',
        'Police Officer',
        'Firefighter',
        'Safety Officer',
        'CCTV Operator',
        'Loss Prevention Officer',
      ],
    ),
    EthiopianCategoryData(
      id: 7,
      name: 'Accounting and Finance',
      slug: 'accounting-and-finance',
      iconName: 'account_balance',
      titles: [
        'Accountant',
        'Junior Accountant',
        'Senior Accountant',
        'Chief Accountant',
        'Auditor',
        'Internal Auditor',
        'External Auditor',
        'Cashier',
        'Bank Teller',
        'Finance Officer',
        'Finance Manager',
        'Credit Officer',
        'Loan Officer',
        'Tax Accountant',
        'Payroll Officer',
        'Budget Officer',
        'Cost Accountant',
        'Financial Analyst',
        'Insurance Officer',
        'Microfinance Officer',
      ],
    ),
    EthiopianCategoryData(
      id: 8,
      name: 'Management and Administration',
      slug: 'management-and-administration',
      iconName: 'business_center',
      titles: [
        'General Manager',
        'Operations Manager',
        'Project Manager',
        'Office Manager',
        'Department Manager',
        'Human Resource Manager',
        'HR Officer',
        'Administrative Officer',
        'Office Assistant',
        'Secretary',
        'Executive Assistant',
        'Receptionist',
        'Personal Assistant',
        'Administrative Manager',
        'Branch Manager',
        'Business Development Manager',
        'Program Manager',
        'Operations Supervisor',
        'General Secretary',
        'Records Officer',
      ],
    ),
    EthiopianCategoryData(
      id: 9,
      name: 'Shopping, Retail and Sales',
      slug: 'shopping-retail-and-sales',
      iconName: 'shopping_bag',
      titles: [
        'Shopkeeper',
        'Shop Assistant',
        'Salesperson',
        'Sales Representative',
        'Sales Manager',
        'Supermarket Cashier',
        'Store Manager',
        'Retail Manager',
        'Merchandiser',
        'Stock Controller',
        'Wholesale Trader',
        'Retail Trader',
        'Shop Supervisor',
        'Market Vendor',
        'Product Distributor',
        'Sales Agent',
        'Customer Sales Officer',
        'Storekeeper',
        'Inventory Controller',
        'Purchasing Assistant',
      ],
    ),
    EthiopianCategoryData(
      id: 10,
      name: 'Marketing and Advertising',
      slug: 'marketing-and-advertising',
      iconName: 'campaign',
      titles: [
        'Marketing Officer',
        'Marketing Manager',
        'Digital Marketer',
        'Social Media Manager',
        'Brand Manager',
        'Advertising Officer',
        'Market Researcher',
        'Sales Promoter',
        'Marketing Assistant',
        'Public Relations Officer',
        'Content Creator',
        'SEO Specialist',
        'Communication Officer',
        'Marketing Consultant',
        'Market Development Officer',
      ],
    ),
    EthiopianCategoryData(
      id: 11,
      name: 'Healthcare and Medical',
      slug: 'healthcare-and-medical',
      iconName: 'local_hospital',
      titles: [
        'Medical Doctor',
        'General Practitioner',
        'Specialist Doctor',
        'Surgeon',
        'Nurse',
        'Midwife',
        'Health Officer',
        'Pharmacist',
        'Pharmacy Technician',
        'Dentist',
        'Dental Assistant',
        'Laboratory Technician',
        'Medical Laboratory Technologist',
        'Radiographer',
        'Physiotherapist',
        'Nutritionist',
        'Anesthetist',
        'Psychiatrist',
        'Psychologist',
        'Medical Receptionist',
        'Public Health Officer',
        'Health Extension Worker',
        'Medical Records Officer',
        'Optometrist',
        'Ambulance Driver',
      ],
    ),
    EthiopianCategoryData(
      id: 12,
      name: 'Transportation and Logistics',
      slug: 'transportation-and-logistics',
      iconName: 'local_shipping',
      titles: [
        'Taxi Driver',
        'Bajaj Driver',
        'Minibus Driver',
        'Bus Driver',
        'Truck Driver',
        'Private Driver',
        'Delivery Driver',
        'Motorcycle Courier',
        'Warehouse Worker',
        'Warehouse Manager',
        'Logistics Officer',
        'Supply Chain Officer',
        'Fleet Manager',
        'Transport Manager',
        'Forklift Operator',
        'Loading Worker',
        'Dispatch Officer',
        'Freight Forwarder',
        'Automotive Mechanic',
        'Vehicle Inspector',
      ],
    ),
    EthiopianCategoryData(
      id: 13,
      name: 'Hotel, Restaurant and Tourism',
      slug: 'hotel-restaurant-and-tourism',
      iconName: 'hotel',
      titles: [
        'Hotel Manager',
        'Hotel Receptionist',
        'Restaurant Manager',
        'Chef',
        'Assistant Chef',
        'Cook',
        'Waiter',
        'Waitress',
        'Bartender',
        'Dishwasher',
        'Kitchen Assistant',
        'Room Attendant',
        'Housekeeping Supervisor',
        'Tour Guide',
        'Tour Operator',
        'Travel Agent',
        'Travel Consultant',
        'Event Organizer',
        'Catering Worker',
        'Baker',
      ],
    ),
    EthiopianCategoryData(
      id: 14,
      name: 'Manufacturing and Industry',
      slug: 'manufacturing-and-industry',
      iconName: 'precision_manufacturing',
      titles: [
        'Factory Worker',
        'Production Worker',
        'Machine Operator',
        'Factory Supervisor',
        'Production Manager',
        'Quality Control Officer',
        'Quality Assurance Officer',
        'Textile Worker',
        'Garment Worker',
        'Tailor',
        'Sewing Machine Operator',
        'Food Processing Worker',
        'Packaging Worker',
        'Industrial Electrician',
        'Industrial Mechanic',
        'Machine Technician',
        'Welding Technician',
        'Production Engineer',
        'Factory Maintenance Worker',
        'Industrial Safety Officer',
      ],
    ),
    EthiopianCategoryData(
      id: 15,
      name: 'Information Technology',
      slug: 'information-technology',
      iconName: 'computer',
      titles: [
        'Software Developer',
        'Flutter Developer',
        'Android Developer',
        'iOS Developer',
        'Web Developer',
        'Frontend Developer',
        'Backend Developer',
        'Full Stack Developer',
        'Laravel Developer',
        'Python Developer',
        'Java Developer',
        'PHP Developer',
        'Database Administrator',
        'Data Analyst',
        'Data Scientist',
        'AI Engineer',
        'Network Engineer',
        'System Administrator',
        'IT Support Officer',
        'Computer Technician',
        'Cybersecurity Analyst',
        'UI/UX Designer',
        'Graphic Designer',
        'IT Project Manager',
        'Software Tester',
      ],
    ),
    EthiopianCategoryData(
      id: 16,
      name: 'Telecommunications',
      slug: 'telecommunications',
      iconName: 'phone_in_talk',
      titles: [
        'Telecom Engineer',
        'Telecom Technician',
        'Fiber Optic Technician',
        'Network Technician',
        'Radio Technician',
        'Mobile Network Engineer',
        'Tower Technician',
        'Telecom Installation Technician',
        'Communication Engineer',
        'Telecom Supervisor',
      ],
    ),
    EthiopianCategoryData(
      id: 17,
      name: 'Media and Communication',
      slug: 'media-and-communication',
      iconName: 'mic',
      titles: [
        'Journalist',
        'Reporter',
        'News Presenter',
        'TV Presenter',
        'Radio Presenter',
        'Editor',
        'Photographer',
        'Videographer',
        'Video Editor',
        'Camera Operator',
        'Film Director',
        'Translator',
        'Interpreter',
        'Content Writer',
        'Copywriter',
        'Graphic Artist',
        'Sound Engineer',
        'Radio Technician',
        'Social Media Content Creator',
        'Public Relations Specialist',
      ],
    ),
    EthiopianCategoryData(
      id: 18,
      name: 'Legal and Government',
      slug: 'legal-and-government',
      iconName: 'gavel',
      titles: [
        'Lawyer',
        'Attorney',
        'Prosecutor',
        'Legal Advisor',
        'Legal Assistant',
        'Court Clerk',
        'Judge',
        'Government Officer',
        'Public Administrator',
        'Policy Analyst',
        'Development Officer',
        'Customs Officer',
        'Immigration Officer',
        'Tax Officer',
        'Government Auditor',
      ],
    ),
    EthiopianCategoryData(
      id: 19,
      name: 'NGO and Humanitarian Work',
      slug: 'ngo-and-humanitarian-work',
      iconName: 'volunteer_activism',
      titles: [
        'Project Officer',
        'Program Officer',
        'Project Coordinator',
        'Community Development Officer',
        'Social Worker',
        'Humanitarian Officer',
        'Field Officer',
        'Monitoring and Evaluation Officer',
        'Data Collector',
        'Enumerator',
        'Research Assistant',
        'Grant Officer',
        'Protection Officer',
        'Child Protection Officer',
        'Gender Officer',
        'WASH Officer',
        'Food Security Officer',
        'Relief Distribution Officer',
        'NGO Administrator',
        'Livelihood Officer',
      ],
    ),
    EthiopianCategoryData(
      id: 20,
      name: 'Beauty, Fashion and Personal Services',
      slug: 'beauty-fashion-and-personal-services',
      iconName: 'spa',
      titles: [
        'Hairdresser',
        'Barber',
        'Makeup Artist',
        'Beautician',
        'Nail Technician',
        'Fashion Designer',
        'Tailor',
        'Shoe Repairer',
        'Shoe Maker',
        'Laundry Service Worker',
        'Fitness Trainer',
        'Personal Trainer',
        'Massage Therapist',
        'Phone Repair Technician',
        'Electronics Repair Technician',
      ],
    ),
    EthiopianCategoryData(
      id: 21,
      name: 'Science and Research',
      slug: 'science-and-research',
      iconName: 'science',
      titles: [
        'Research Scientist',
        'Researcher',
        'Biologist',
        'Chemist',
        'Physicist',
        'Geologist',
        'Hydrologist',
        'Environmental Scientist',
        'Statistician',
        'Economist',
        'Sociologist',
        'Psychologist',
        'Laboratory Researcher',
        'GIS Specialist',
        'Data Researcher',
      ],
    ),
    EthiopianCategoryData(
      id: 22,
      name: 'Mining and Energy',
      slug: 'mining-and-energy',
      iconName: 'bolt',
      titles: [
        'Mining Engineer',
        'Miner',
        'Geophysicist',
        'Drilling Technician',
        'Quarry Worker',
        'Petroleum Engineer',
        'Renewable Energy Engineer',
        'Solar Technician',
        'Electrical Power Engineer',
        'Energy Technician',
      ],
    ),
    EthiopianCategoryData(
      id: 23,
      name: 'Freelance and Self-Employment',
      slug: 'freelance-and-self-employment',
      iconName: 'work',
      titles: [
        'Freelance Writer',
        'Freelance Developer',
        'Freelance Designer',
        'Freelance Translator',
        'Freelance Photographer',
        'Independent Consultant',
        'Online Seller',
        'Small Business Owner',
        'Private Tutor',
        'Independent Contractor',
      ],
    ),
    EthiopianCategoryData(
      id: 24,
      name: 'Sports and Recreation',
      slug: 'sports-and-recreation',
      iconName: 'sports_soccer',
      titles: [
        'Football Player',
        'Football Coach',
        'Sports Coach',
        'Referee',
        'Fitness Instructor',
        'Gym Instructor',
        'Athlete',
        'Sports Administrator',
        'Sports Physiotherapist',
        'Sports Event Organizer',
      ],
    ),
    EthiopianCategoryData(
      id: 25,
      name: 'Water, Sanitation and Environment',
      slug: 'water-sanitation-and-environment',
      iconName: 'water_drop',
      titles: [
        'Water Technician',
        'Water Supply Operator',
        'Sanitation Worker',
        'Waste Collector',
        'Recycling Worker',
        'Environmental Officer',
        'Waste Management Officer',
        'Water Engineer',
        'Sewerage Technician',
        'Environmental Health Officer',
      ],
    ),
    EthiopianCategoryData(
      id: 26,
      name: 'Crafts and Traditional Occupations',
      slug: 'crafts-and-traditional-occupations',
      iconName: 'brush',
      titles: [
        'Potter',
        'Basket Weaver',
        'Traditional Weaver',
        'Leather Worker',
        'Blacksmith',
        'Goldsmith',
        'Handicraft Maker',
        'Traditional Clothing Maker',
        'Beadwork Artisan',
        'Traditional Carpenter',
      ],
    ),
    EthiopianCategoryData(
      id: 27,
      name: 'Aviation and Airport',
      slug: 'aviation-and-airport',
      iconName: 'flight',
      titles: [
        'Pilot',
        'Flight Attendant',
        'Aircraft Technician',
        'Airport Ground Staff',
        'Airport Security Officer',
        'Air Traffic Controller',
        'Aviation Engineer',
        'Baggage Handler',
        'Cargo Officer',
        'Airport Operations Officer',
      ],
    ),
    EthiopianCategoryData(
      id: 28,
      name: 'Childcare and Social Care',
      slug: 'childcare-and-social-care',
      iconName: 'child_care',
      titles: [
        'Childcare Worker',
        'Daycare Assistant',
        'Elderly Caregiver',
        'Disability Support Worker',
        'Community Care Worker',
        'Social Service Officer',
        'Rehabilitation Assistant',
        'Orphanage Caregiver',
        'Family Support Worker',
        'Special Needs Assistant',
      ],
    ),
    EthiopianCategoryData(
      id: 29,
      name: 'Procurement and Tender Services',
      slug: 'procurement-and-tender-services',
      iconName: 'receipt_long',
      titles: [
        'Procurement Officer',
        'Tender Officer',
        'Bid Preparation Specialist',
        'Contract Manager',
        'Purchasing Officer',
        'Supply Officer',
        'Procurement Manager',
        'Tender Documentation Specialist',
        'Vendor Registration Officer',
        'Contract Administrator',
      ],
    ),
    EthiopianCategoryData(
      id: 30,
      name: 'Other and Emerging Jobs',
      slug: 'other-and-emerging-jobs',
      iconName: 'lightbulb',
      titles: [
        'Digital Payment Agent',
        'Mobile Money Agent',
        'E-commerce Manager',
        'Online Customer Support Agent',
        'Data Entry Operator',
        'Document Controller',
        'Virtual Assistant',
        'Remote Assistant',
        'Drone Operator',
        'Robotics Technician',
        'AI Data Annotator',
        'Digital Literacy Trainer',
        'E-learning Coordinator',
        'Cybersecurity Technician',
        'Renewable Energy Installer',
      ],
    ),
  ];

  static List<String>? _allTitlesCache;

  /// Returns flat list of all 475 Ethiopian job titles
  static List<String> get allTitles {
    if (_allTitlesCache != null) return _allTitlesCache!;
    final list = <String>[];
    for (final cat in categories) {
      list.addAll(cat.titles);
    }
    _allTitlesCache = list;
    return list;
  }

  /// Suggest titles matching query prefix or substring
  static List<String> searchTitles(
    String query, {
    String? categoryName,
    int limit = 10,
  }) {
    if (query.trim().isEmpty) {
      if (categoryName != null) {
        final cat = categories.firstWhere(
          (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
          orElse: () => categories.first,
        );
        return cat.titles.take(limit).toList();
      }
      return allTitles.take(limit).toList();
    }

    final q = query.trim().toLowerCase();
    List<String> pool = allTitles;
    if (categoryName != null &&
        categoryName.isNotEmpty &&
        categoryName != 'All') {
      final found = categories
          .where((c) => c.name.toLowerCase() == categoryName.toLowerCase())
          .toList();
      if (found.isNotEmpty) {
        pool = found.first.titles;
      }
    }

    // Exact prefix matches first, then contains matches
    final prefixMatches = pool
        .where((t) => t.toLowerCase().startsWith(q))
        .toList();
    final containsMatches = pool
        .where(
          (t) => !t.toLowerCase().startsWith(q) && t.toLowerCase().contains(q),
        )
        .toList();

    return [...prefixMatches, ...containsMatches].take(limit).toList();
  }

  /// Find category for a given job title
  static EthiopianCategoryData? findCategoryForTitle(String title) {
    final lower = title.toLowerCase().trim();
    for (final cat in categories) {
      for (final t in cat.titles) {
        if (t.toLowerCase() == lower) return cat;
      }
    }
    // Fuzzy check
    for (final cat in categories) {
      for (final t in cat.titles) {
        if (lower.contains(t.toLowerCase()) ||
            t.toLowerCase().contains(lower)) {
          return cat;
        }
      }
    }
    return null;
  }
}

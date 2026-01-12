import 'package:flutter/material.dart';
import 'package:login/pages/home/home_view_model.dart';
import 'package:login/pages/home/widgets/home_carousel.dart';
import 'package:login/pages/home/widgets/home_header.dart';
import 'package:login/pages/home/widgets/home_map_layer.dart';
import 'package:login/pages/home/widgets/magic_search_button.dart';
import 'package:login/pages/home/widgets/magic_search_overlay.dart';
import 'package:login/providers/location_list_provider.dart';
import 'package:login/providers/map_state_provider.dart';
import 'package:login/providers/nav_bar/visibility_provider.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = HomeViewModel(
      locationListManager: context.read<LocationListManager>(),
      mapStateProvider: context.read<MapStateProvider>(),
      bottomNavVisibilityProvider: context.read<BottomNavVisibilityProvider>(),
    );
    _viewModel.init();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<HomeViewModel>(
        builder: (context, viewModel, _) {
          return Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: HomeMapLayer(
                    onMapTap: viewModel.onMapTap,
                    onSearchThisArea: viewModel.searchThisArea,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: HomeHeader(
                    currentListType: viewModel.currentListType,
                    onListTypeChanged: viewModel.setListType,
                  ),
                ),
                HomeCarousel(
                  pageController: viewModel.pageController,
                  locations: viewModel.locations,
                  selectedMarkerId: viewModel.selectedMarkerId,
                  bottomNavVisible: viewModel.bottomNavVisible,
                  onPageChanged: viewModel.onCarouselPageChanged,
                  onScrollStart: viewModel.onCarouselScrollStart,
                  onLocationSelected: viewModel.onLocationSelected,
                ),
                Positioned(
                  top: 80,
                  right: 20,
                  child: MagicSearchButton(
                    onPressed: () => viewModel.toggleSearchOverlay(true),
                  ),
                ),
                if (viewModel.showSearchOverlay)
                  MagicSearchOverlay(
                    controller: viewModel.searchController,
                    onClose: () => viewModel.toggleSearchOverlay(false),
                    onSubmit: viewModel.submitMagicSearch,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

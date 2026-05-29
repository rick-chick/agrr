// Tests for `catalog/farm_size_catalog.rs` (Ruby parity under test/domain/public_plan/).


    // Ruby: test "all returns three farm sizes"
    #[test]
    fn all_returns_three_farm_sizes() {
        let sizes = FarmSizeCatalog::all();
        assert_eq!(sizes.len(), 3);
        assert_eq!(sizes[0].id, "home_garden");
        assert_eq!(sizes[0].area_sqm, 30);
    }

    // Ruby: test "find_by_id matches id string"
    #[test]
    fn find_by_id_matches_id_string() {
        let size = FarmSizeCatalog::find_by_id("rental_farm").expect("found");
        assert_eq!(size.area_sqm, 300);
    }

    // Ruby: test "find_by_id matches area_sqm integer"
    #[test]
    fn find_by_id_matches_area_sqm_integer() {
        let size = FarmSizeCatalog::find_by_id("50").expect("found");
        assert_eq!(size.id, "community_garden");
    }

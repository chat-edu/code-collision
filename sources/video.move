module chat_edu::video {

    use std::signer;
    use std::string::String;
    use std::vector;

    use aptos_std::simple_map::{Self, SimpleMap};
    use aptos_std::smart_vector;
    use aptos_std::smart_vector::SmartVector;
    use aptos_framework::coin;
    use aptos_framework::coin::Coin;
    use chat_edu::credits;

    use chat_edu::credits::Credits;

    friend chat_edu::course;

    // constants

    const WATCH_COST: u64 = 50;

    // error codes

    const E_ALREADY_INITIALIZED: u64 = 0;
    const E_NOT_INITIALIZED: u64 = 1;
    const E_VIDEO_ALREADY_EXISTS: u64 = 2;
    const E_VIDEO_NOT_FOUND: u64 = 3;

    // structs

    struct Videos has key {
        mapping: SimpleMap<String, Video>
    }

    struct Video has store {
        id: String,
        owner: address,
        user_ids: SmartVector<address>,
        file_id: String,
        credits: Coin<Credits>
    }

    public(friend) fun init(course: &signer) {
        assert_videos_not_initialized(signer::address_of(course));
        move_to(course, Videos {
            mapping: simple_map::new()
        });
    }

    public(friend) fun add_video(course_address: address, id: String, owner: address, file_id: String) acquires Videos {
        assert_videos_initialized(course_address);
        assert_video_doesnt_exist(course_address, id);
        let videos = borrow_global_mut<Videos>(course_address);
        let user_ids = smart_vector::new<address>();
        smart_vector::push_back(&mut user_ids, owner);
        simple_map::add(&mut videos.mapping, id, Video {
            id,
            owner,
            user_ids,
            file_id,
            credits: coin::zero()
        });
    }

    public entry fun join_video(account: &signer, course_address: address, id: String) acquires Videos {
        assert_videos_initialized(course_address);
        assert_video_exists(course_address, id);
        let fee = coin::withdraw<Credits>(account, WATCH_COST);
        credits::burn(coin::extract(&mut fee, WATCH_COST / 2));
        add_credits(course_address, id, fee);
        let videos = borrow_global_mut<Videos>(course_address);
        let video = simple_map::borrow_mut(&mut videos.mapping, &id);
        smart_vector::push_back(&mut video.user_ids, signer::address_of(account));
    }

    public(friend) fun add_credits(course_address: address, id: String, credits: Coin<Credits>) acquires Videos {
        assert_videos_initialized(course_address);
        assert_video_exists(course_address, id);
        let videos = borrow_global_mut<Videos>(course_address);
        let video = simple_map::borrow_mut(&mut videos.mapping, &id);
        coin::merge(&mut video.credits, credits);
    }

    public(friend) fun withdraw_credits(course_address: address, id: String): Coin<Credits> acquires Videos {
        assert_videos_initialized(course_address);
        assert_video_exists(course_address, id);
        let videos = borrow_global_mut<Videos>(course_address);
        let video = simple_map::borrow_mut(&mut videos.mapping, &id);
        coin::extract_all(&mut video.credits)
    }

    public(friend) fun withdraw_all_credits(user_address: address, course_address: address): Coin<Credits> acquires Videos {
        assert_videos_initialized(course_address);
        let videos = borrow_global_mut<Videos>(course_address);
        let total_credits = coin::zero();
        vector::for_each(simple_map::keys(&videos.mapping), |video_id| {
            let video = simple_map::borrow_mut(&mut videos.mapping, &video_id);
            if(video.owner == user_address) {
                coin::merge(&mut total_credits, coin::extract_all(&mut video.credits));
            }
        });
        total_credits
    }

    // getters

    #[view]
    public fun get_user_file_credits(course_address: address, user_address: address): u64 acquires Videos {
        assert_videos_initialized(course_address);
        let videos = borrow_global<Videos>(course_address);
        let total_credits = 0;
        vector::for_each(simple_map::keys(&videos.mapping), |video_id| {
            let video = simple_map::borrow(&videos.mapping, &video_id);
            if (video.owner == user_address) {
                total_credits = total_credits + coin::value(&video.credits);
            }
        });
        total_credits
    }

    #[view]
    public fun get_video_credits(course_address: address, id: String): u64 acquires Videos {
        assert_videos_initialized(course_address);
        assert_video_exists(course_address, id);
        let videos = borrow_global<Videos>(course_address);
        let video = simple_map::borrow(&videos.mapping, &id);
        coin::value(&video.credits)
    }

    // asserts

    fun assert_videos_not_initialized(course_address: address) {
        assert!(!exists<Videos>(course_address), E_ALREADY_INITIALIZED);
    }

    fun assert_videos_initialized(course_address: address) {
        assert!(exists<Videos>(course_address), E_NOT_INITIALIZED);
    }

    fun assert_video_doesnt_exist(course_address: address, id: String) acquires Videos {
        let videos = borrow_global<Videos>(course_address);
        assert!(!simple_map::contains_key(&videos.mapping, &id), E_VIDEO_ALREADY_EXISTS);
    }

    fun assert_video_exists(course_address: address, id: String) acquires Videos {
        let videos = borrow_global<Videos>(course_address);
        assert!(simple_map::contains_key(&videos.mapping, &id), E_VIDEO_NOT_FOUND);
    }
}
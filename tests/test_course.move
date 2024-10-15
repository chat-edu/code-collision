#[test_only]
module chat_edu::test_course {

    use std::signer;
    use std::string;
    use chat_edu::course;
    
    const COURSE_ID: vector<u8> = b"Course ID";
    
    #[test(admin=@chat_edu)]
    fun test_init(admin: &signer) {
        course::init(admin);
    }

    #[test(not_admin=@0x100)]
    #[expected_failure(abort_code=course::E_NOT_ADMIN)]
    fun test_init_not_admin(not_admin: &signer) {
        course::init(not_admin);
    }

    #[test(admin=@chat_edu)]
    #[expected_failure(abort_code=course::E_ALREADY_INITIALIZED)]
    fun test_init_twice(admin: &signer) {
        course::init(admin);
        course::init(admin);
    }
    
    #[test(chat_edu=@chat_edu, account=@0x100)]
    fun test_create_course(chat_edu: &signer, account: &signer) {
        course::init(chat_edu);
        course::create_course(account, string::utf8(COURSE_ID));
    }

    #[test(account=@0x100)]
    #[expected_failure(abort_code=course::E_NOT_INITIALIZED)]
    fun test_create_course_before_init(account: &signer) {
        course::create_course(account, string::utf8(COURSE_ID));
    }

    #[test(chat_edu=@chat_edu, account=@0x100)]
    #[expected_failure(abort_code=course::E_COURSE_ALREADY_CREATED)]
    fun test_create_course_twice(chat_edu: &signer, account: &signer) {
        course::init(chat_edu);
        course::create_course(account, string::utf8(COURSE_ID));
        course::create_course(account, string::utf8(COURSE_ID));
    }

    #[test(chat_edu=@chat_edu, account=@0x100, joining_user=@0x101)]
    fun test_join_course(chat_edu: &signer, account: &signer, joining_user: &signer) {
        course::init(chat_edu);
        course::create_course(account, string::utf8(COURSE_ID));
        course::join_course(joining_user, string::utf8(COURSE_ID));
        assert!(course::get_user_in_course(string::utf8(COURSE_ID), signer::address_of(joining_user)), 1);
    }

    #[test(chat_edu=@chat_edu, account=@0x100, joining_user=@0x101)]
    #[expected_failure(abort_code=course::E_COURSE_NOT_FOUND)]
    fun test_join_course_doesnt_exist(chat_edu: &signer, account: &signer, joining_user: &signer) {
        course::init(chat_edu);
        course::create_course(account, string::utf8(COURSE_ID), );
        course::join_course(joining_user, string::utf8(b"Non-existent Course"));
    }

    

    #[test(chat_edu=@chat_edu, account=@0x100, joining_user=@0x101)]
    #[expected_failure(abort_code=course::E_ALREADY_JOINED)]
    fun test_join_course_twice(chat_edu: &signer, account: &signer, joining_user: &signer) {
        course::init(chat_edu);
        course::create_course(account, string::utf8(COURSE_ID));
        course::join_course(joining_user, string::utf8(COURSE_ID));
        course::join_course(joining_user, string::utf8(COURSE_ID));
    }

    #[test(chat_edu=@chat_edu, account=@0x100, joining_user=@0x101)]
    fun test_leave_course(chat_edu: &signer, account: &signer, joining_user: &signer) {
        course::init(chat_edu);
        course::create_course(account, string::utf8(COURSE_ID));
        course::join_course(joining_user, string::utf8(COURSE_ID));
        course::leave_course(joining_user, string::utf8(COURSE_ID));
        assert!(!course::get_user_in_course(string::utf8(COURSE_ID), signer::address_of(joining_user)), 1);
    }

    #[test(chat_edu=@chat_edu, account=@0x100, joining_user=@0x101)]
    #[expected_failure(abort_code=course::E_NOT_JOINED)]
    fun test_leave_course_not_in_course(chat_edu: &signer, account: &signer, joining_user: &signer) {
        course::init(chat_edu);
        course::create_course(
            account,
            string::utf8(COURSE_ID),
        );
        course::leave_course(joining_user, string::utf8(COURSE_ID));
    }
}

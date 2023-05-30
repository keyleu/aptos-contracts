module overmind::birthday_bot {
    use aptos_std::table::{Table, contains, borrow};
    use aptos_std::table;
    use std::signer;
    use aptos_framework::account;
    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::timestamp;
    use std::vector;

    //
    // Errors
    //
    const ERROR_DISTRIBUTION_STORE_EXIST: u64 = 0;
    const ERROR_DISTRIBUTION_STORE_DOES_NOT_EXIST: u64 = 1;
    const ERROR_LENGTHS_NOT_EQUAL: u64 = 2;
    const ERROR_BIRTHDAY_GIFT_DOES_NOT_EXIST: u64 = 3;
    const ERROR_BIRTHDAY_TIMESTAMP_SECONDS_HAS_NOT_PASSED: u64 = 4;

    //
    // Data structures
    //
    struct BirthdayGift has drop, store {
        amount: u64,
        birthday_timestamp_seconds: u64,
    }

    struct DistributionStore has key {
        birthday_gifts: Table<address, BirthdayGift>,
        signer_capability: account::SignerCapability,
    }

    //
    // Assert functions
    //
    public fun assert_distribution_store_exists(
        account_address: address,
    ){
        // TODO: assert that `DistributionStore` exists
        assert!(exists<DistributionStore>(account_address), ERROR_DISTRIBUTION_STORE_DOES_NOT_EXIST);
    }

    public fun assert_distribution_store_does_not_exist(
        account_address: address,
    ){
        // TODO: assert that `DistributionStore` does not exist
        assert!(!exists<DistributionStore>(account_address), ERROR_DISTRIBUTION_STORE_EXIST);
    }

    public fun assert_lengths_are_equal(
        addresses: vector<address>,
        amounts: vector<u64>,
        timestamps: vector<u64>
    ){
        assert!(vector::length(&addresses) == vector::length(&amounts), ERROR_LENGTHS_NOT_EQUAL);
        assert!(vector::length(&addresses) == vector::length(&timestamps), ERROR_LENGTHS_NOT_EQUAL)
    }

    public fun assert_birthday_gift_exists(
        distribution_address: address,
        address: address,
    ) acquires DistributionStore {
        // TODO: assert that `birthday_gifts` exists
        let distribution_store = borrow_global<DistributionStore>(distribution_address);
        assert!(contains(&distribution_store.birthday_gifts, address), ERROR_BIRTHDAY_GIFT_DOES_NOT_EXIST);
    }

    public fun assert_birthday_timestamp_seconds_has_passed(
        distribution_address: address,
        address: address,
    ) acquires DistributionStore {
        // TODO: assert that the current timestamp is greater than or equal to `birthday_timestamp_seconds`
        let distribution_store = borrow_global<DistributionStore>(distribution_address);
        let birthday_gift = borrow(&distribution_store.birthday_gifts, address);
        assert!(timestamp::now_seconds() > birthday_gift.birthday_timestamp_seconds, ERROR_BIRTHDAY_TIMESTAMP_SECONDS_HAS_NOT_PASSED)
    }

    //
    // Entry functions
    //
    /**
    * Initializes birthday gift distribution contract
    * @param account - account signer executing the function
    * @param addresses - list of addresses that can claim their birthday gifts
    * @param amounts  - list of amounts for birthday gifts
    * @param birthday_timestamps - list of birthday timestamps in seconds (only claimable after this timestamp has passed)
    **/
    public entry fun initialize_distribution(
        account: &signer,
        addresses: vector<address>,
        amounts: vector<u64>,
        birthday_timestamps: vector<u64>
    ) {
        // TODO: check `DistributionStore` does not exist
        let signer_address = signer::address_of(account);
        assert_distribution_store_does_not_exist(signer_address);
        // TODO: check all lengths of `addresses`, `amounts`, and `birthday_timestamps` are equal
        assert_lengths_are_equal(addresses, amounts, birthday_timestamps);
        // TODO: create resource account
        let (resource_account_signer, resource_account_cap) = account::create_resource_account(account, vector::empty<u8>());
        // TODO: register Aptos coin to resource account
        coin::register<AptosCoin>(&resource_account_signer);
        // TODO: loop through the lists and push items to birthday_gifts table
        let i = 0;
        let sum = 0;
        let end = vector::length(&birthday_timestamps);
        let table_gifts = table::new<address, BirthdayGift>();
        loop {
            if (i >= end) break;
            sum = sum + *vector::borrow(&amounts, i);
            table::add<address, BirthdayGift>(&mut table_gifts, *vector::borrow(&addresses, i), BirthdayGift { amount: *vector::borrow(&amounts, i), birthday_timestamp_seconds: *vector::borrow(&birthday_timestamps, i)});
            i = i + 1;
        };

        let distribution_store = DistributionStore {
            birthday_gifts: table_gifts,
            signer_capability: resource_account_cap,
        };
        // TODO: transfer the sum of all items in `amounts` from initiator to resource account
        coin::transfer<AptosCoin>(account, signer::address_of(&resource_account_signer), sum);

        // TODO: move_to resource `DistributionStore` to account signer
        move_to(account, distribution_store)
    }

    /**
    * Add birthday gift to `DistributionStore.birthday_gifts`
    * @param account - account signer executing the function
    * @param address - address that can claim the birthday gift
    * @param amount  - amount for the birthday gift
    * @param birthday_timestamp_seconds - birthday timestamp in seconds (only claimable after this timestamp has passed)
    **/
    public entry fun add_birthday_gift(
        account: &signer,
        address: address,
        amount: u64,
        birthday_timestamp_seconds: u64
    ) acquires DistributionStore {
        // TODO: check that the distribution store exists
        let signer_address = signer::address_of(account);
        assert_distribution_store_exists(signer_address);
        // TODO: set new birthday gift to new `amount` and `birthday_timestamp_seconds` (birthday_gift already exists, sum `amounts` and override the `birthday_timestamp_seconds`
        let distribution_store = borrow_global_mut<DistributionStore>(signer_address);
        if (contains(&distribution_store.birthday_gifts, address)) {
            let birthday_gift = BirthdayGift {
                amount: table::borrow(&distribution_store.birthday_gifts, address).amount + amount,
                birthday_timestamp_seconds,
            };
            table::upsert(&mut distribution_store.birthday_gifts, address, birthday_gift);
        }else{
            let birthday_gift = BirthdayGift {
                amount,
                birthday_timestamp_seconds,
            };
            table::add(&mut distribution_store.birthday_gifts, address, birthday_gift);
        };
        // TODO: transfer the `amount` from initiator to resource account
        let resource_signer = account::create_signer_with_capability(&distribution_store.signer_capability);
        coin::transfer<AptosCoin>(account, signer::address_of(&resource_signer), amount);
    }

    /**
    * Remove birthday gift from `DistributionStore.birthday_gifts`
    * @param account - account signer executing the function
    * @param address - `birthday_gifts` address
    **/
    public entry fun remove_birthday_gift(
        account: &signer,
        address: address,
    ) acquires DistributionStore {
        // TODO: check that the distribution store exists
        let signer_address = signer::address_of(account);
        assert_distribution_store_exists(signer_address);
        // TODO: if `birthday_gifts` exists, remove `birthday_gift` from table and transfer `amount` from resource account to initiator
        let distribution_store = borrow_global_mut<DistributionStore>(signer_address);
        if (contains(&distribution_store.birthday_gifts, address)) {
            let amount = table::borrow<address, BirthdayGift>(&distribution_store.birthday_gifts, address).amount;
            table::remove<address, BirthdayGift>(&mut distribution_store.birthday_gifts, address);
            let resource_signer = account::create_signer_with_capability(&distribution_store.signer_capability);
            coin::transfer<AptosCoin>(&resource_signer, signer::address_of(account), amount);
        }
    }

    /**
    * Claim birthday gift from `DistributionStore.birthday_gifts`
    * @param account - account signer executing the function
    * @param distribution_address - distribution contract address
    **/
    public entry fun claim_birthday_gift(
        account: &signer,
        distribution_address: address,
    ) acquires DistributionStore {
        // TODO: check that the distribution store exists
                assert_distribution_store_exists(distribution_address);
        // TODO: check that the `birthday_gift` exists
        let signer_address = signer::address_of(account);
        assert_birthday_gift_exists(distribution_address, signer_address);
        // TODO: check that the `birthday_timestamp_seconds` has passed
        assert_birthday_timestamp_seconds_has_passed(distribution_address, signer_address);
        // TODO: remove `birthday_gift` from table and transfer `amount` from resource account to initiator
        let distribution_store = borrow_global_mut<DistributionStore>(distribution_address);
        let amount = table::borrow<address, BirthdayGift>(&distribution_store.birthday_gifts, signer_address).amount;
        table::remove<address, BirthdayGift>(&mut distribution_store.birthday_gifts, signer_address);
        let resource_signer = account::create_signer_with_capability(&distribution_store.signer_capability);
        coin::transfer<AptosCoin>(&resource_signer, signer::address_of(account), amount);
    }
}

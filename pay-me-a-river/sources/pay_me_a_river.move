module overmind::pay_me_a_river {
    use aptos_std::table::{Table, contains, borrow, borrow_mut, new, add};
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin::{Coin, extract, withdraw, value, deposit, extract_all, merge};
    use aptos_framework::timestamp;
    use std::signer;

    const ESENDER_CAN_NOT_BE_RECEIVER: u64 = 1;
    const ENUMBER_INVALID: u64 = 2;
    const EPAYMENT_DOES_NOT_EXIST: u64 = 3;
    const ESTREAM_DOES_NOT_EXIST: u64 = 4;
    const ESTREAM_IS_ACTIVE: u64 = 5;
    const ESIGNER_ADDRESS_IS_NOT_SENDER_OR_RECEIVER: u64 = 6;

    struct Stream has store {
        sender: address,
        receiver: address,
        length_in_seconds: u64,
        start_time: u64,
        coins: Coin<AptosCoin>,
    }

    struct Payments has key {
        streams: Table<address, Stream>,
    }

    inline fun check_sender_is_not_receiver(sender: address, receiver: address) {
        assert!(sender != receiver, ESENDER_CAN_NOT_BE_RECEIVER);
    }

    inline fun check_number_is_valid(number: u64) {
        assert!(number > 0, ENUMBER_INVALID);
    }

    inline fun check_payment_exists(sender_address: address) {
        assert!(exists<Payments>(sender_address), EPAYMENT_DOES_NOT_EXIST);
    }

    inline fun check_stream_exists(payments: &Payments, stream_address: address) {
        assert!(contains(&payments.streams, stream_address), ESTREAM_DOES_NOT_EXIST);
    }

    inline fun check_stream_is_not_active(payments: &Payments, stream_address: address) {
        let stream = borrow(&payments.streams, stream_address);
        assert!(stream.start_time == 0, ESTREAM_IS_ACTIVE);
    }

    inline fun check_signer_address_is_sender_or_receiver(
        signer_address: address,
        sender_address: address,
        receiver_address: address
    ) {
        assert!(signer_address == sender_address || signer_address == receiver_address, ESIGNER_ADDRESS_IS_NOT_SENDER_OR_RECEIVER);
    }

    inline fun calculate_stream_claim_amount(total_amount: u64, start_time: u64, length_in_seconds: u64): u64 {
        let time_now = timestamp::now_seconds();
        if (start_time > time_now){
            0
        }else if(time_now >= start_time + length_in_seconds){
            total_amount
        }else{
            total_amount * (time_now - start_time)/length_in_seconds
        }
    }

    public entry fun create_stream(
        signer: &signer,
        receiver_address: address,
        amount: u64,
        length_in_seconds: u64
    ) acquires Payments {
        let signer_address = signer::address_of(signer);
        check_sender_is_not_receiver(signer_address, receiver_address);
        check_number_is_valid(amount);
        if (!exists<Payments>(signer_address)) {
            let initialize = Payments {
                streams: new<address, Stream>(),
            };
            move_to(signer, initialize);
        };
        let payments = borrow_global_mut<Payments>(signer_address);
        let coin = withdraw<AptosCoin>(signer, amount);
        if (!contains(&mut payments.streams, receiver_address)) {
            let stream = Stream {
                sender: signer_address,
                receiver: receiver_address,
                length_in_seconds,
                start_time: 0,
                coins: coin,
            };
            add(&mut payments.streams, receiver_address, stream);
        }else{
            let stream = borrow_mut(&mut payments.streams, receiver_address);
            stream.length_in_seconds = length_in_seconds;
            stream.start_time = 0;
            merge<AptosCoin>(&mut stream.coins, coin);
        }
    }

    public entry fun accept_stream(signer: &signer, sender_address: address) acquires Payments {
        let signer_address = signer::address_of(signer);
        check_payment_exists(sender_address);
        let payments = borrow_global_mut<Payments>(sender_address);
        check_stream_exists(payments, signer_address);
        check_stream_is_not_active(payments, signer_address);
        let stream = borrow_mut(&mut payments.streams, signer_address);
        stream.start_time = timestamp::now_seconds();
    }

    public entry fun claim_stream(signer: &signer, sender_address: address) acquires Payments {
        let signer_address = signer::address_of(signer);
        check_payment_exists(sender_address);
        let payments = borrow_global_mut<Payments>(sender_address);
        check_stream_exists(payments, signer_address);
        let stream = borrow_mut(&mut payments.streams, signer_address);
        let claim_amount = calculate_stream_claim_amount(value(&stream.coins), stream.start_time, stream.length_in_seconds);
        let coin = extract(&mut stream.coins, claim_amount);
        let now = timestamp::now_seconds();
        stream.length_in_seconds = (now - stream.start_time)/stream.length_in_seconds;
        stream.start_time = now;
        deposit(signer_address, coin);
    }

    public entry fun cancel_stream(
        signer: &signer,
        sender_address: address,
        receiver_address: address
    ) acquires Payments {
        let signer_address = signer::address_of(signer);
        check_payment_exists(sender_address);
        let payments = borrow_global_mut<Payments>(sender_address);
        check_stream_exists(payments, receiver_address);
        let stream = borrow_mut(&mut payments.streams, receiver_address);
        check_signer_address_is_sender_or_receiver(signer_address, sender_address, receiver_address);
        let coin = extract_all(&mut stream.coins);
        deposit(sender_address, coin);
    }

    #[view]
    public fun get_stream(sender_address: address, receiver_address: address): (u64, u64, u64) acquires Payments {
        check_payment_exists(sender_address);
        let payments = borrow_global_mut<Payments>(sender_address);
        check_stream_exists(payments, receiver_address);
        let stream = borrow(&mut payments.streams, receiver_address);
        (stream.length_in_seconds, stream.start_time, value(&stream.coins))
    }
}
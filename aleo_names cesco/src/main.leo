import credits.leo;

// The 'program' program.
program aleo_names.aleo {
    struct AleoName {
        data0: u128, // The first 128 bits of the ASCII domain name
        data1: u128, // The next 128 bits of the ASCII domain name
        data2: u128, // The next 128 bits of the ASCII domain name
        data3: u128, // The next 128 bits of the ASCII domain name
    }

    struct BaseURI {
        data0: u128, // Part 1 of the base uri in bits. Bits should be the representation of the hexadecimal bytes for the ASCII text of the URL
        data1: u128,
        data2: u128,
        data3: u128
    }

    record NFT {
        owner: address,
        data: TokenId,
        edition: scalar
    }

    struct ResolverIndex {
        name: field, // The name_hash
        category: u128 // The type of the resolver, can contain 16 characters in maximum
    }

    struct TokenId {
        data0: u128, // data1 to data3 store the AleoName structure
        data1: u128,
        data2: u128,
        data3: u128,
        parent: field
    }


    // Mappings for different data structures
    mapping nft_owners: field => address;
    mapping names: field => TokenId; // Mapping from a field(hash name) to an TokenId structure
    mapping primary_names: address => field; // Mapping from an address to a primary name
    mapping resolvers: ResolverIndex => AleoName; // Mapping from a ResolverIndex structure to an AleoName structure(string)
    mapping general_settings: u8 => u128;
    mapping toggle_settings: u8 => u32;


    // Validates that the given AleoName contains only valid ASCII characters for a domain name and is not just zeros.
    function is_available(name: AleoName) -> bool {
        // Check if the sum of the ASCII bits is zero
        let sum: u128 = name.data0 + name.data1 + name.data2 + name.data3;
        assert(sum != 0u128);
        let n1_valid: bool = validate_name_bit(name.data0);
        let n2_valid: bool = validate_name_bit(name.data1);
        let n3_valid: bool = validate_name_bit(name.data2);
        let n4_valid: bool = validate_name_bit(name.data3);
        return n1_valid && n2_valid && n3_valid && n4_valid;
    }

    // Initializes the collection with the given total, symbol, and base URI. Can only be called once.
    transition initialize_collection(
        public total: u128,
        public symbol: u128,
        public base_uri: BaseURI,
    ) {
        assert_eq(self.caller, aleo17vy26rpdhqx4598y5gp7nvaa9rk7tnvl6ufhvvf4calsrrqdaqyshdsf5z);
        return then finalize(total, symbol, base_uri);
    }


    // Finalizes the initialization by setting the general and toggle settings in the contract's state.
    finalize initialize_collection(
        public total: u128,
        public symbol: u128,
        public base_uri: BaseURI,
    ) {
        // Ensure initialize cannot be called twice!
        let toggle_settings_status: u32 = toggle_settings.get_or_use(0u8, 0u32);
        let is_initialized: u32 = toggle_settings_status & 1u32;
        assert_eq(is_initialized, 0u32);

        general_settings.set(0u8, total); // This setting is for the Leo wallet, no real effect on the contract
        general_settings.set(1u8, total); // This setting is for the Leo wallet, no real effect on the contract
        general_settings.set(2u8, symbol); // Symbol for the NFT
        general_settings.set(3u8, base_uri.data0); // Base URI for NFT
        general_settings.set(4u8, base_uri.data1);
        general_settings.set(5u8, base_uri.data2);
        general_settings.set(6u8, base_uri.data3);
        toggle_settings.set(0u8, 1u32);
        toggle_settings.set(1u8, 0u32); // block height when mint is allowed
    }


    // Sets the block height at which minting becomes possible. Only callable by the contract owner.
    transition set_mint_block(public mint_block: u32) {
        assert_eq(self.caller, aleo17vy26rpdhqx4598y5gp7nvaa9rk7tnvl6ufhvvf4calsrrqdaqyshdsf5z);
        return then finalize(mint_block);
    }
    // Finalizes setting the mint block height in the contract's toggle settings.
    finalize set_mint_block(public mint_block: u32) {
        let toggle_settings_status: u32 = toggle_settings.get(0u8);
        let is_initialized_and_not_frozen: u32 = toggle_settings_status & 9u32;
        assert_eq(is_initialized_and_not_frozen, 1u32);

        toggle_settings.set(1u8, mint_block);
    }

    // Updates the base URI for the NFTs. Only callable by the contract owner.
    transition update_base_uri(public base_uri: BaseURI) {
        assert_eq(self.caller, aleo17vy26rpdhqx4598y5gp7nvaa9rk7tnvl6ufhvvf4calsrrqdaqyshdsf5z);
        return then finalize(base_uri);
    }
    
    // Finalizes updating the base URI in the contract's general settings.
    finalize update_base_uri(public base_uri: BaseURI) {
        let toggle_settings_status: u32 = toggle_settings.get(0u8);
        let is_initialized_and_not_frozen: u32 = toggle_settings_status & 9u32;
        assert_eq(is_initialized_and_not_frozen, 1u32);

        general_settings.set(3u8, base_uri.data0); // Base URI for NFT
        general_settings.set(4u8, base_uri.data1);
        general_settings.set(5u8, base_uri.data2);
        general_settings.set(6u8, base_uri.data3);
    }

    // Updates the toggle settings to enable or disable minting, whitelist requirements, or to freeze the contract.
    transition update_toggle_settings(public toggle_settings_bitstring: u32) {
        assert_eq(self.caller, aleo17vy26rpdhqx4598y5gp7nvaa9rk7tnvl6ufhvvf4calsrrqdaqyshdsf5z);
        return then finalize(toggle_settings_bitstring);
    }

    // Finalizes updating the toggle settings in the contract's state.
    finalize update_toggle_settings(public toggle_settings_bitstring: u32) {
        let toggle_settings_status: u32 = toggle_settings.get(0u8);
        let is_initialized_and_not_frozen: u32 = toggle_settings_status & 9u32;
        assert_eq(is_initialized_and_not_frozen, 1u32);

        let still_initialized: u32 = toggle_settings_bitstring & 1u32;
        assert_eq(still_initialized, 1u32);

        toggle_settings.set(0u8, toggle_settings_bitstring);
    }

    // Registers a new name by creating a new NFT, after validating the name and transferring the required credits.
    transition register(
        name: AleoName,
        receiver: address,
        pay_record: credits.leo/credits
    ) -> NFT {
        // Validate the name before registration
        assert(is_available(name));
        let credit_receiver: address = aleo17vy26rpdhqx4598y5gp7nvaa9rk7tnvl6ufhvvf4calsrrqdaqyshdsf5z;
        let price: u64 = 5000000u64;
        credits.leo/transfer_private_to_public(pay_record, credit_receiver, price);
        let token_id: TokenId = TokenId {
            data0: name.data0,
            data1: name.data1,
            data2: name.data2,
            data3: name.data3,
            parent: 0field
        };
        let name_hash: field = BHP256::hash_to_field(token_id);
        let nft: NFT = NFT {
            owner: receiver,
            data: token_id,
            edition: 0scalar
        };
        return nft then finalize(name_hash, token_id);
    }

    // Finalizes the registration by updating the names mapping with the new name hash and associated TokenId.
    finalize register(name_hash: field, token_id: TokenId) {
        // Check if the name has already been registered
        assert_eq(names.contains(name_hash), false);

        let mint_block: u32 = toggle_settings.get(1u8);

        let toggle_settings_status: u32 = toggle_settings.get(0u8);
        let collection_settings_met: u32 = toggle_settings_status & 11u32;
        assert_eq(collection_settings_met, 3u32);

        names.set(name_hash, token_id);
    }


    // Registers a subdomain by creating a new NFT for the subdomain and updating the parent NFT's information.
    transition register_sub(
        name: AleoName,
        receiver: address,
        parent: NFT
    ) -> (NFT, NFT) {
        assert(is_available(name));
        let parent_hash: field = BHP256::hash_to_field(parent.data);
        let token_id: TokenId = TokenId {
            data0: name.data0,
            data1: name.data1,
            data2: name.data2,
            data3: name.data3,
            parent: parent_hash
        };
        let name_hash: field = BHP256::hash_to_field(token_id);
        let nft: NFT = NFT { owner: receiver, data: token_id, edition: 0scalar};
        let new_parent: NFT = NFT { owner: parent.owner, data: parent.data, edition: parent.edition };
        return (nft, new_parent) then finalize(name_hash, token_id);
    }

    // Finalizes the registration of the subdomain by updating the names mapping.
    finalize register_sub(name_hash: field, token_id: TokenId) {
        assert_eq(names.contains(name_hash), false);

        let mint_block: u32 = toggle_settings.get(1u8);

        let toggle_settings_status: u32 = toggle_settings.get(0u8);
        let collection_settings_met: u32 = toggle_settings_status & 11u32;
        assert_eq(collection_settings_met, 3u32);

        names.set(name_hash, token_id);
    }

    // Registers a subdomain of a public domain, ensuring the caller is the owner of the parent domain.
    transition register_sub_public(
        name: AleoName,
        receiver: address,
        parent: field
    ) -> NFT {
        // Validate the name before registration
        assert(is_available(name));
        let token_id: TokenId = TokenId {
            data0: name.data0,
            data1: name.data1,
            data2: name.data2,
            data3: name.data3,
            parent: parent
        };
        let name_hash: field = BHP256::hash_to_field(token_id);
        let nft: NFT = NFT { owner: receiver, data: token_id, edition: 0scalar};
        return nft then finalize(name_hash, token_id, self.caller);
    }

    // Finalizes the public subdomain registration by updating the names mapping.
    finalize register_sub_public(name_hash: field, token_id: TokenId, caller: address) {
        // Check if the callar is the owner of the parent name
        assert_eq(caller, nft_owners.get(token_id.parent));
        // Check if the name has already been registered
        assert_eq(names.contains(name_hash), false);

        // Ensure mint block height is less than current block height
        let mint_block: u32 = toggle_settings.get(1u8);

        // Ensure minting is allowed, and is initialized,
        let toggle_settings_status: u32 = toggle_settings.get(0u8);
        // frozen & minting & initialized flags = 0b0000...1011 = 11u32
        // what the settings should be = 0b0000...0011 = 3u32
        let collection_settings_met: u32 = toggle_settings_status & 11u32;
        assert_eq(collection_settings_met, 3u32);

        names.set(name_hash, token_id);
    }

    // A transition intended to provide proof of NFT ownership without revealing the NFT itself, though it fails by design.
    transition authorize(
        nft: NFT
    )
    {
        return then finalize();
    }

    // Finalize block for the authorize transition, designed to always fail to complete the proof without transferring the NFT.
    finalize authorize(
    )
    {
        assert_eq(0u8, 1u8);
    }


    // Burns an NFT by removing its corresponding name hash from the names mapping.
    transition burn(
        nft: NFT
    )
    {
        let name_hash: field = BHP256::hash_to_field(nft.data);
        return then finalize(name_hash);
    }

    // Finalizes the burning process by removing the NFT from the names mapping.
    finalize burn(name_hash: field)
    {
        names.remove(name_hash);
    }

    // Checks if a name is available by verifying that it is not already in the names mapping.
    transition is_avaiable(
        name_hash: field
    ) -> bool {
        return then finalize(name_hash);
    }
    // Finalizes the availability check by asserting the name hash does not exist in the names mapping.
    finalize is_avaiable(name_hash: field) {
        assert_eq(names.contains(name_hash), false);
    }


    // Transfers an NFT to a private address without revealing the receiver's address publicly.
    transition transfer_privatly(
        nft: NFT,
        private receiver: address
    ) -> NFT
    {
        return NFT {
            owner: receiver,
            data: nft.data,
            edition: 0scalar
        };
    }

    // Transfers an NFT to a public address and updates the nft_owners mapping.
    transition transfer_publicly(
        private receiver: address,
        private name_hash: field
    )
    {
        return then finalize(receiver, name_hash, self.caller);
    }

    // Finalizes the public transfer by updating the nft_owners mapping.
    finalize transfer_publicly(
        receiver: address,
        name_hash: field,
        caller: address
    )
    {
        assert_eq(caller, nft_owners.get(name_hash));
        nft_owners.set(name_hash, receiver);
    }

    // Converts a privately owned NFT to a publicly owned one by updating the nft_owners mapping.
    transition convert_private_to_public(
        nft: NFT
    )
    {
        let name_hash: field = BHP256::hash_to_field(nft.data);
        return then finalize(self.caller, name_hash);
    }

    // Finalizes the conversion to public ownership by updating the nft_owners mapping.
    finalize convert_private_to_public(
        public owner: address,
        public name_hash: field,
    )
    {
        nft_owners.set(name_hash, owner);
    }


    // Converts a publicly owned NFT to a privately owned one by removing it from the nft_owners mapping.
    transition convert_public_to_private(
        private token_id: TokenId
    ) -> NFT
    {
        let name_hash: field = BHP256::hash_to_field(token_id);
        return NFT {
            owner: self.caller,
            data: token_id,
            edition: 0scalar
        } then finalize(self.caller, name_hash);
    }
    // Finalizes the conversion to private ownership by removing the NFT from the nft_owners mapping.
    finalize convert_public_to_private(
        public owner: address,
        public name_hash: field
    )
    {
        assert_eq(owner, nft_owners.get(name_hash));
        nft_owners.remove(name_hash);
    }


    // Sets the primary name for an address, linking it to a name hash in the primary_names mapping.
    transition set_primary_name(name_hash: field) {
        return then finalize(name_hash, self.caller);
    }
    
    // Finalizes setting the primary name by updating the primary_names mapping.
    finalize set_primary_name(name_hash: field, owner: address) {
        assert_eq(owner, nft_owners.get(name_hash));

        primary_names.set(owner, name_hash);
    }

    // Unsets the primary name for the caller by removing their entry from the primary_names mapping.
    transition remove_primary_name() {
        return then finalize(self.caller);
    }

    // Finalizes unsetting the primary name by removing the entry from the primary_names mapping.
    finalize remove_primary_name(owner: address) {
        primary_names.remove(owner);
    }

    // Sets a resolver for a name by adding an entry to the resolvers mapping.
    transition set_ans_resolver(name_hash: field, category: u128, content: AleoName) {
        let name: AleoName = AleoName { data0: category, data1: 0u128, data2: 0u128, data3: 0u128 };
        assert(is_available(name));
        return then finalize(name_hash, self.caller, category, content);
    }

    // Finalizes setting the resolver by updating the resolvers mapping.
    finalize set_ans_resolver(name_hash: field, owner: address, category: u128, content: AleoName) {
        assert_eq(owner, nft_owners.get(name_hash));

        let resolver_index: ResolverIndex = ResolverIndex { name: name_hash, category: category };
        resolvers.set(resolver_index, content);
    }

    // Unsets a resolver for a name by removing the entry from the resolvers mapping.
    transition free_ans_resolver(name_hash: field, category: u128) {
        return then finalize(name_hash, self.caller, category);
    }

    // Finalizes unsetting the resolver by removing the entry from the resolvers mapping.
    finalize free_ans_resolver(name_hash: field, owner: address, category: u128) {
        assert_eq(owner, nft_owners.get(name_hash));

        let resolver_index: ResolverIndex = ResolverIndex { name: name_hash, category: category };
        resolvers.remove(resolver_index);
    }


    // inlines

    // Utility function to validate individual 128-bit blocks of an AleoName to ensure each byte represents a valid ASCII character.
    inline validate_name_bit(val: u128) -> bool {
        let mask: u128 = 255u128;
        for i: u8 in 0u8 .. 16u8 {
            let new: u128 = val.shr(i * 8u8);
            let b: u128 = new & mask;
            // Check if the ASCII bit is valid, 0-9, a-z, -, _
            if (! (b == 0u128 || b == 45u128 || b == 95u128 || (b >= 48u128 && b <= 57u128) || (b >= 97u128 && b <= 122u128))) {
                return false;
            }
        }
        return true;
    }
}
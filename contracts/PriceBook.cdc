import EnumerableSet from "./EnumerableSet.cdc"

/*
 * A contract to keep track of the prices elected by fraction
 * holders to determine the Reserve Price
 */

 pub contract PriceBook { 

    // Fraction Information
    // Fraction supply by Vault Id
    pub let fractionSupply: {UInt256: UInt256}
    
    // A function to decrease supply in the mapping
    // CHANGE TO ACCESS ACCOUNT SO THAT ONLY FRACTION.CDC can call the function
    pub fun removeFromSupply(_ vaultId: UInt256, _ amount: UInt256) {
        self.fractionSupply[vaultId] = self.fractionSupply[vaultId]! - amount
    }
    
    // A function to increase the supply in the mapping
    // CHANGE TO ACCESS ACCOUNT SO THAT ONLY FRACTION.CDC can call the function
    pub fun addToSupply(_ vaultId: UInt256, _ amount: UInt256) {
        if self.fractionSupply[vaultId] == nil {
            self.fractionSupply[vaultId] = amount
        } else {
            self.fractionSupply[vaultId] = self.fractionSupply[vaultId]! + amount
        }
    }
    
    pub struct ReserveInfo {
        pub var voting: UInt256
        pub var reserve: UFix64

        init(_ voting: UInt256, _ reserve: UFix64){
            self.voting = voting
            self.reserve = reserve
        }
    }

    //Vault information//
    //CHANGE PRICES TO ACCOUNT ACCESS
    //Array of prices with more than 1% voting for them by vaultId
    pub let prices: {UInt256: EnumerableSet.UFix64Set}
    //All prices and the number voting for them
    pub let priceToCount: {UInt256: {UFix64: UInt256}}
    //The price each fraction is bidding
    pub let fractionPrices: {UInt256: {UInt64: UFix64}}

    // add to a price count
    // add price to reserve calc if 1% are voting for it
    //TODO: CHANGE TO access(account)
    pub fun addToPrice(_ vaultId: UInt256, _ amount: UInt256, _ price: UFix64) {
        let nested = self.priceToCount[vaultId] ?? {}
        nested[price] = nested[price]! + amount
        self.priceToCount[vaultId] = nested
        //TODO: Check the math adds up
        if self.priceToCount[vaultId]![price]! * 100 >= self.fractionSupply[vaultId]! && !self.prices[vaultId]!.contains(price) {
            self.prices[vaultId]!.add(price)
        }
    }

    // remove a price count
    // remove price from reserve calc if less than 1% are voting for it
    //TODO: CHANGE TO access(account) so that the Fraction contract can remove bids when fractions are burned
    pub fun removeFromPrice(_ vaultId: UInt256, _ amount: UInt256, _ oldPrice: UFix64) {
        let nested = self.priceToCount[vaultId] ?? {}
        nested[oldPrice] = nested[oldPrice]! - amount
        self.priceToCount[vaultId] = nested
        //TODO: Check the math adds up
        if self.priceToCount[vaultId]![oldPrice]! * 100 < self.fractionSupply[vaultId]! && !self.prices[vaultId]!.contains(oldPrice) {
            self.prices[vaultId]!.remove(oldPrice)
        }
    }

    access(contract) fun slice(_ array: [UFix64], _ begin: Integer, _ last: Integer): [UFix64] {
        var arr: [UFix64] = []
        var i = begin
        while i < last {
            arr.append(array[i])
            i = i + 1
        }
        return arr
    }

    access(contract) fun sort(_ array: [UFix64]): [UFix64] {
        //create copy because arguments are constant
        var arr = array
        var length = arr.length
        //base case
        if length < 2 {
            return arr
        }

        //position of the partition
        var currentPosition = 0

        var i = 1
        while i < length {
            if arr[i] <= arr[0] {
                currentPosition = currentPosition + 1
                arr[i] <-> arr[currentPosition]
            }
        }

        //swap
        arr[0] <-> arr[currentPosition]

        var left: [UFix64] = self.sort(self.slice(arr, 0, currentPosition))
        var right: [UFix64] = self.sort(self.slice(arr, currentPosition + 1, length))

        //mergin the arrays
        arr = left
        arr.append(arr[currentPosition])
        arr.appendAll(right)
        return arr
    }

    pub fun reservePrice(_ vaultId: UInt256): ReserveInfo {

        var tempPrices = self.prices[vaultId]!.values()
        tempPrices = self.sort(tempPrices)
        var voting: UInt256 = 0
        var x: Int = 0
        while x < tempPrices.length {   
            if tempPrices[x] != 0.0 {
                voting = voting + self.priceToCount[vaultId]![tempPrices[x]]!
            }
            x = x + 1
        }

        var reserve = 0.0 
        var count: UInt256 = 0
        var y = 0
        while y < tempPrices.length {
            if tempPrices[y] != 0.0 {
                count = count + self.priceToCount[vaultId]![tempPrices[y]]!
            }
            if count * 2 >= voting {
                reserve = tempPrices[y]
                break
            }
        }
        return ReserveInfo(voting, reserve)
    }

    init() {
        self.fractionSupply = {}
        self.prices = {}
        self.priceToCount = {}
        self.fractionPrices = {}
    }
 }
 
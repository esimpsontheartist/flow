import Clock from "../../contracts/Clock.cdc"

transaction(time: UFix64) {
    prepare(signer: AuthAccount) {
        Clock.enable()
    }
    execute {
        Clock.tick(time)
    }
}
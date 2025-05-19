
local function colorPack(hex)
    return {hexToRGB(hex)}
end

return {
    {  -- 0 default
        colorPack("fbfaf7"), --white
        colorPack("c7c093"), --yellow
        colorPack("b3a286"), --dark yellow
        colorPack("85917a"), --y green
        colorPack("5c7873"), --green
        colorPack("466673"), --blue green
        colorPack("3a4a6b"), --blue
        colorPack("302c5e"), --dark blue
        colorPack("090909"), --black
    },
    { -- 1 night
        colorPack("a2b8b1"),--white
        colorPack("719797"),--yellow
        colorPack("557b78"),--dark yellow
        colorPack("396d7d"),--y green
        colorPack("3c5f66"),--green
        colorPack("254351"),--blue green
        colorPack("19374b"),--blue
        colorPack("1f2439"),--dark blue
        colorPack("230019"),--black
    },
    { -- 2 snake
        colorPack("66f390"),--white
        colorPack("00d459"),--yellow
        colorPack("15bd5e"),--dark yellow
        colorPack("039a5d"),--y green
        colorPack("00755c"),--green
        colorPack("005858"),--blue green
        colorPack("003645"),--blue
        colorPack("001d37"),--dark blue
        colorPack("000c2c"),--black
    },
    {
        colorPack("ffffff"),--white
        colorPack("6ceded"),--yellow
        colorPack("6cb9c9"),--dark yellow
        colorPack("6d85a5"),--y green
        colorPack("6e5181"),--green
        colorPack("6f1d5c"),--blue green
        colorPack("4f1446"),--blue
        colorPack("2e0a30"),--dark blue
        colorPack("0d001a"),--black
    },
}


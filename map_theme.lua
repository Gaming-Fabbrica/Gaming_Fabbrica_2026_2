local Rules = require("rules")

local THEMES = {
  forest = {
    background = "assets/maps/forest/bg.png",
    treeAnimated = true,
    variants = {
      stone = {
        "assets/maps/forest/stone1.png",
        "assets/maps/forest/stone2.png",
        "assets/maps/forest/stone3.png",
        "assets/maps/forest/stone4.png",
      },
      bush = {
        "assets/maps/forest/bush1.png",
        "assets/maps/forest/bush2.png",
        "assets/maps/forest/bush3.png",
        "assets/maps/forest/bush4.png",
        "assets/maps/forest/bush5.png",
        "assets/maps/forest/bush6.png",
      },
      tree = {
        "assets/maps/forest/tree1.png",
        "assets/maps/forest/tree2.png",
        "assets/maps/forest/tree3.png",
        "assets/maps/forest/tree4.png",
        "assets/maps/forest/tree5.png",
        "assets/maps/forest/tree6.png",
      },
    },
  },
  swamp = {
    background = "assets/maps/swamp/bg.png",
    treeAnimated = false,
    variants = {
      stone = {
        "assets/maps/swamp/stone1.png",
        "assets/maps/swamp/stone2.png",
        "assets/maps/swamp/stone3.png",
        "assets/maps/swamp/stone4.png",
      },
      bush = {
        "assets/maps/swamp/bush1.png",
        "assets/maps/swamp/bush2.png",
        "assets/maps/swamp/bush3.png",
        "assets/maps/swamp/bush4.png",
        "assets/maps/swamp/bush5.png",
        "assets/maps/swamp/bush6.png",
      },
      tree = {
        "assets/maps/swamp/tree1.png",
        "assets/maps/swamp/tree2.png",
        "assets/maps/swamp/tree3.png",
        "assets/maps/swamp/tree4.png",
        "assets/maps/swamp/tree5.png",
        "assets/maps/swamp/tree6.png",
      },
    },
  },
}

local MapTheme = {}

function MapTheme.getName()
  if Rules.SWAMP then
    return "swamp"
  end
  return "forest"
end

function MapTheme.get()
  return THEMES[MapTheme.getName()]
end

function MapTheme.getBackgroundPath()
  return MapTheme.get().background
end

function MapTheme.getVariants(kind)
  return MapTheme.get().variants[kind]
end

function MapTheme.areTreesAnimated()
  return MapTheme.get().treeAnimated
end

return MapTheme

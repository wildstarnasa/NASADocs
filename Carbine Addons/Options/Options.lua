-----------------------------------------------------------------------------------------------
-- Client Lua Script for Options
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Apollo"
require "Window"
require "GenericDialog"

local OptionsAddon = {}

local karStatusTextString =
{
	"Options_AddonInvalid",
	"Options_AddonOff",
	"Options_AddonError",
	"Options_AddonLoaded",
	"Options_AddonSuspended",
	"Options_AddonRunningWithErrors",
	"",
}

local karStatusText =
{
	"CRB_ModuleStatus_Invalid",
	"CRB_ModuleStatus_NotLoaded",
	"CRB_ModuleStatus_ParsingError",
	"CRB_ModuleStatus_Loaded",
	"CRB_ModuleStatus_Suspended",
	"CRB_ModuleStatus_RunningWithErrors",
	"CRB_ModuleStatus_RunningOk",
}

local karSortingConstants = 
{
	[OptionsScreen.CodeEnumAddonStatus.ParsingError] 		= "1",
	[OptionsScreen.CodeEnumAddonStatus.Invalid] 			= "1",
	[OptionsScreen.CodeEnumAddonStatus.Suspended] 			= "1",
	[OptionsScreen.CodeEnumAddonStatus.RunningWithError] 	= "2",
	[OptionsScreen.CodeEnumAddonStatus.NotLoaded] 			= "3",
	[OptionsScreen.CodeEnumAddonStatus.Loaded] 				= "4",
	[OptionsScreen.CodeEnumAddonStatus.RunningOk] 			= "5",
}

local karStatusColors =
{
	ApolloColor.new("xkcdReddish"),
	ApolloColor.new("AddonNotLoaded"),
	ApolloColor.new("xkcdReddish"),
	ApolloColor.new("AddonLoaded"),
	ApolloColor.new("xkcdReddish"),
	ApolloColor.new("AddonWarning"),
	ApolloColor.new("AddonOk"),
}

local EnumAddonColumns =
{
	Status 			= 1,
	Name 			= 2,
	Folder 			= 3,
	Author			= 4,
	Memory 			= 5,
	Calls 			= 6,
	TotalTime 		= 7,
	MaxTime 		= 8,
	MsPerFrame      = 9,
	LastModified 	= 10,
	APIVersion 		= 11,
	Replaces 		= 12,
	LoadSetting 	= 13,
}

local ktVideoSettingLevels =
{
	["UltraHigh"] =
	{
		["video.framerateMax"] = 100,
		["lod.viewDistance"] = 920,
		["lod.farFogDistance"] = 2048,
		["camera.distanceMax"] = 32,
		["lod.textureLodMin"] = 0,
		["lod.textureFilter"] = 2,
		["lod.landLod"] = 1,
		["lod.clutterDistance"] = 128,
		["lod.clutterDensity"] = 2,
		["draw.shadows"] = true,
		["lod.shadowMapSize"] = 4096,
		["lod.renderTargetScale"] = 1,
		["fxaa.preset"] = 5,
		["fxaa.enable"] = true,
		["world.propScreenHeightPercentMin"] = 5,
		["particle.envParticleScale"] = 1,
		["spell.visualSuppression"] = 0,
		["spell.visualSuppressedAlpha"] = 0,
	},
	["High"] =
	{
		["video.framerateMax"] = 100,
		["lod.viewDistance"] = 768,
		["lod.farFogDistance"] = 2048,
		["camera.distanceMax"] = 32,
		["lod.textureLodMin"] = 0,
		["lod.textureFilter"] = 2,
		["lod.landLod"] = 1,
		["lod.clutterDistance"] = 96,
		["lod.clutterDensity"] = 2,
		["draw.shadows"] = true,
		["lod.shadowMapSize"] = 2048,
		["lod.renderTargetScale"] = 1,
		["fxaa.preset"] = 4,
		["fxaa.enable"] = true,
		["world.propScreenHeightPercentMin"] = 5,
		["particle.envParticleScale"] = 1,
		["spell.visualSuppression"] = 0,
		["spell.visualSuppressedAlpha"] = 0,
	},
	["Medium"] =
	{
		["video.framerateMax"] = 100,
		["lod.viewDistance"] = 640,
		["lod.farFogDistance"] = 2048,
		["camera.distanceMax"] = 32,
		["lod.textureLodMin"] = 1,
		["lod.textureFilter"] = 2,
		["lod.landLod"] = 1,
		["lod.clutterDistance"] = 64,
		["lod.clutterDensity"] = 1,
		["draw.shadows"] = true,
		["lod.shadowMapSize"] = 2048,
		["lod.renderTargetScale"] = 1,
		["fxaa.preset"] = 3,
		["fxaa.enable"] = true,
		["world.propScreenHeightPercentMin"] = 8,
		["particle.envParticleScale"] = 0.5,
		["spell.visualSuppression"] = 0.5,
		["spell.visualSuppressedAlpha"] = 0,
	},
	["Low"] =
	{
		["video.framerateMax"] = 100,
		["lod.viewDistance"] = 512,
		["lod.farFogDistance"] = 1536,
		["camera.distanceMax"] = 32,
		["lod.textureLodMin"] = 2,
		["lod.textureFilter"] = 1,
		["lod.landLod"] = 0,
		["lod.clutterDistance"] = 48,
		["lod.clutterDensity"] = 0,
		["draw.shadows"] = true,
		["lod.shadowMapSize"] = 1024,
		["lod.renderTargetScale"] = 0.75,
		["fxaa.preset"] = 1,
		["fxaa.enable"] = true,
		["world.propScreenHeightPercentMin"] = 12,
		["particle.envParticleScale"] = 0.25,
		["spell.visualSuppression"] = 0.9,
		["spell.visualSuppressedAlpha"] = 0,
	},
	["UltraLow"] =
	{
		["video.framerateMax"] = 100,
		["lod.viewDistance"] = 256,
		["lod.farFogDistance"] = 1024,
		["camera.distanceMax"] = 32,
		["lod.textureLodMin"] = 2,
		["lod.textureFilter"] = 0,
		["lod.landLod"] = 0,
		["lod.clutterDistance"] = 32,
		["lod.clutterDensity"] = 0,
		["draw.shadows"] = false,
		["lod.shadowMapSize"] = 1024,
		["lod.renderTargetScale"] = 0.5,
		["fxaa.preset"] = 0,
		["fxaa.enable"] = false,
		["world.propScreenHeightPercentMin"] = 12,
		["particle.envParticleScale"] = 0.1,
		["spell.visualSuppression"] = 1.0,
		["spell.visualSuppressedAlpha"] = 0,
	}
}

local ktTelegraphColorOptions =
{
	-- self
	{
		strLabel = "Options_TelegraphColorSelf",
		tSets =
		{
			[0] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityDefault_12",
				consoleVarOutlineOpacity = "spell.outlineOpacityDefault_12",
				crColor = ApolloColor.new(22.0/255.0, 209.0/255.0, 255.0/255.0)
			},
			[1] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityDeuteranopia_12",
				consoleVarOutlineOpacity = "spell.outlineOpacityDeuteranopia_12",
				crColor = ApolloColor.new(59.0/255.0, 20.0/255.0, 175.0/255.0)
			},
			[2] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityProtanopia_12",
				consoleVarOutlineOpacity = "spell.outlineOpacityProtanopia_12",
				crColor = ApolloColor.new(44.0/255.0, 23.0/255.0, 177.0/255.0)
			},
			[3] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityTritanopia_12",
				consoleVarOutlineOpacity = "spell.outlineOpacityTritanopia_12",
				crColor = ApolloColor.new(76.0/255.0, 16.0/255.0, 174.0/255.0)
			},
			[4] =
			{
				bReadOnlyColors = false,
				consoleVarFillOpacity = "spell.fillOpacityCustom1_12",
				consoleVarOutlineOpacity = "spell.outlineOpacityCustom1_12",
				consoleVarColorR = "spell.custom1SelfTelegraphColorR",
				consoleVarColorG = "spell.custom1SelfTelegraphColorG",
				consoleVarColorB = "spell.custom1SelfTelegraphColorB",
			},
			[5] =
			{
				bReadOnlyColors = false,
				consoleVarFillOpacity = "spell.fillOpacityCustom2_12",
				consoleVarOutlineOpacity = "spell.outlineOpacityCustom2_12",
				consoleVarColorR = "spell.custom2SelfTelegraphColorR",
				consoleVarColorG = "spell.custom2SelfTelegraphColorG",
				consoleVarColorB = "spell.custom2SelfTelegraphColorB",
			}
		}
	},
	{
		strLabel = "Options_TelegraphColorEnemyPlayerBeneficial",
		tSets =
		{
			[0] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityDefault_56",
				consoleVarOutlineOpacity = "spell.outlineOpacityDefault_56",
				crColor = ApolloColor.new(230.0/255.0, 56.0/255.0, 255.0/255.0)
			},
			[1] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityDeuteranopia_56",
				consoleVarOutlineOpacity = "spell.outlineOpacityDeuteranopia_56",
				crColor = ApolloColor.new(220.0/255.0, 0.0/255.0, 85.0/255.0)
			},
			[2] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityProtanopia_56",
				consoleVarOutlineOpacity = "spell.outlineOpacityProtanopia_56",
				crColor = ApolloColor.new(0.0/255.0, 158.0/255.0, 142.0/255.0)
			},
			[3] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityTritanopia_56",
				consoleVarOutlineOpacity = "spell.outlineOpacityTritanopia_56",
				crColor = ApolloColor.new(255.0/255.0, 144.0/255.0, 0.0/255.0)
			},
			[4] =
			{
				bReadOnlyColors = false,
				consoleVarFillOpacity = "spell.fillOpacityCustom1_56",
				consoleVarOutlineOpacity = "spell.outlineOpacityCustom1_56",
				consoleVarColorR = "spell.custom1EnemyPlayerBeneficialTelegraphColorR",
				consoleVarColorG = "spell.custom1EnemyPlayerBeneficialTelegraphColorG",
				consoleVarColorB = "spell.custom1EnemyPlayerBeneficialTelegraphColorB",
			},
			[5] =
			{
				bReadOnlyColors = false,
				consoleVarFillOpacity = "spell.fillOpacityCustom2_56",
				consoleVarOutlineOpacity = "spell.outlineOpacityCustom2_56",
				consoleVarColorR = "spell.custom2EnemyPlayerBeneficialTelegraphColorR",
				consoleVarColorG = "spell.custom2EnemyPlayerBeneficialTelegraphColorG",
				consoleVarColorB = "spell.custom2EnemyPlayerBeneficialTelegraphColorB",
			}
		}
	},
	{
		strLabel = "Options_TelegraphColorEnemyPlayerDetrimental",
		tSets =
		{
			[0] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityDefault_34",
				consoleVarOutlineOpacity = "spell.outlineOpacityDefault_34",
				crColor = ApolloColor.new(255.0/255.0, 44.0/255.0, 25.0/255.0)
			},
			[1] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityDeuteranopia_34",
				consoleVarOutlineOpacity = "spell.outlineOpacityDeuteranopia_34",
				crColor = ApolloColor.new(255.0/255.0, 129.0/255.0, 0.0/255.0)
			},
			[2] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityProtanopia_34",
				consoleVarOutlineOpacity = "spell.outlineOpacityProtanopia_34",
				crColor = ApolloColor.new(255.0/255.0, 211.0/255.0, 0.0/255.0)
			},
			[3] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityTritanopia_34",
				consoleVarOutlineOpacity = "spell.outlineOpacityTritanopia_34",
				crColor = ApolloColor.new(255.0/255.0, 0.0/255.0, 0.0/255.0)
			},
			[4] =
			{
				bReadOnlyColors = false,
				consoleVarFillOpacity = "spell.fillOpacityCustom1_34",
				consoleVarOutlineOpacity = "spell.outlineOpacityCustom1_34",
				consoleVarColorR = "spell.custom1EnemyPlayerDetrimentalTelegraphColorR",
				consoleVarColorG = "spell.custom1EnemyPlayerDetrimentalTelegraphColorG",
				consoleVarColorB = "spell.custom1EnemyPlayerDetrimentalTelegraphColorB",
			},
			[5] =
			{
				bReadOnlyColors = false,
				consoleVarFillOpacity = "spell.fillOpacityCustom2_34",
				consoleVarOutlineOpacity = "spell.outlineOpacityCustom2_34",
				consoleVarColorR = "spell.custom2EnemyPlayerDetrimentalTelegraphColorR",
				consoleVarColorG = "spell.custom2EnemyPlayerDetrimentalTelegraphColorG",
				consoleVarColorB = "spell.custom2EnemyPlayerDetrimentalTelegraphColorB",
			}
		}
	},
	{
		strLabel = "Options_TelegraphColorEnemyNPCBeneficial",
		tSets =
		{
			[0] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityDefault_78",
				consoleVarOutlineOpacity = "spell.outlineOpacityDefault_78",
				crColor = ApolloColor.new(230.0/255.0, 56.0/255.0, 255.0/255.0)
			},
			[1] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityDeuteranopia_78",
				consoleVarOutlineOpacity = "spell.outlineOpacityDeuteranopia_78",
				crColor = ApolloColor.new(220.0/255.0, 0.0/255.0, 85.0/255.0)
			},
			[2] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityProtanopia_78",
				consoleVarOutlineOpacity = "spell.outlineOpacityProtanopia_78",
				crColor = ApolloColor.new(0.0/255.0, 158.0/255.0, 142.0/255.0)
			},
			[3] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityTritanopia_78",
				consoleVarOutlineOpacity = "spell.outlineOpacityTritanopia_78",
				crColor = ApolloColor.new(255.0/255.0, 144.0/255.0, 0.0/255.0)
			},
			[4] =
			{
				bReadOnlyColors = false,
				consoleVarFillOpacity = "spell.fillOpacityCustom1_78",
				consoleVarOutlineOpacity = "spell.outlineOpacityCustom1_78",
				consoleVarColorR = "spell.custom1EnemyNPCBeneficialTelegraphColorR",
				consoleVarColorG = "spell.custom1EnemyNPCBeneficialTelegraphColorG",
				consoleVarColorB = "spell.custom1EnemyNPCBeneficialTelegraphColorB",
			},
			[5] =
			{
				bReadOnlyColors = false,
				consoleVarFillOpacity = "spell.fillOpacityCustom2_78",
				consoleVarOutlineOpacity = "spell.outlineOpacityCustom2_78",
				consoleVarColorR = "spell.custom2EnemyNPCBeneficialTelegraphColorR",
				consoleVarColorG = "spell.custom2EnemyNPCBeneficialTelegraphColorG",
				consoleVarColorB = "spell.custom2EnemyNPCBeneficialTelegraphColorB",
			}
		}
	},
	{
		strLabel = "Options_TelegraphColorEnemyNPCDetrimental",
		tSets =
		{
			[0] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityDefault_34",
				consoleVarOutlineOpacity = "spell.outlineOpacityDefault_34",
				crColor = ApolloColor.new(255.0/255.0, 44.0/255.0, 25.0/255.0)
			},
			[1] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityDeuteranopia_34",
				consoleVarOutlineOpacity = "spell.outlineOpacityDeuteranopia_34",
				crColor = ApolloColor.new(255.0/255.0, 129.0/255.0, 0.0/255.0)
			},
			[2] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityProtanopia_34",
				consoleVarOutlineOpacity = "spell.outlineOpacityProtanopia_34",
				crColor = ApolloColor.new(255.0/255.0, 211.0/255.0, 0.0/255.0)
			},
			[3] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityTritanopia_34",
				consoleVarOutlineOpacity = "spell.outlineOpacityTritanopia_34",
				crColor = ApolloColor.new(255.0/255.0, 0.0/255.0, 0.0/255.0)
			},
			[4] =
			{
				bReadOnlyColors = false,
				consoleVarFillOpacity = "spell.fillOpacityCustom1_34",
				consoleVarOutlineOpacity = "spell.outlineOpacityCustom1_34",
				consoleVarColorR = "spell.custom1EnemyNPCDetrimentalTelegraphColorR",
				consoleVarColorG = "spell.custom1EnemyNPCDetrimentalTelegraphColorG",
				consoleVarColorB = "spell.custom1EnemyNPCDetrimentalTelegraphColorB",
			},
			[5] =
			{
				bReadOnlyColors = false,
				consoleVarFillOpacity = "spell.fillOpacityCustom2_34",
				consoleVarOutlineOpacity = "spell.outlineOpacityCustom2_34",
				consoleVarColorR = "spell.custom2EnemyNPCDetrimentalTelegraphColorR",
				consoleVarColorG = "spell.custom2EnemyNPCDetrimentalTelegraphColorG",
				consoleVarColorB = "spell.custom2EnemyNPCDetrimentalTelegraphColorB",
			}
		}
	},
	{
		strLabel = "Options_TelegraphColorAllyBeneficial",
		tSets =
		{
			[0] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityDefault_56",
				consoleVarOutlineOpacity = "spell.outlineOpacityDefault_56",
				crColor = ApolloColor.new(52.0/255.0, 216.0/255.0, 0.0/255.0)
			},
			[1] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityDeuteranopia_56",
				consoleVarOutlineOpacity = "spell.outlineOpacityDeuteranopia_56",
				crColor = ApolloColor.new(128.0/255.0, 232.0/255.0, 0.0/255.0)
			},
			[2] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityProtanopia_56",
				consoleVarOutlineOpacity = "spell.outlineOpacityProtanopia_56",
				crColor = ApolloColor.new(255.0/255.0, 0.0/255.0, 0.0/255.0)
			},
			[3] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityTritanopia_56",
				consoleVarOutlineOpacity = "spell.outlineOpacityTritanopia_56",
				crColor = ApolloColor.new(0.0/255.0, 160.0/255.0, 138.0/255.0)
			},
			[4] =
			{
				bReadOnlyColors = false,
				consoleVarFillOpacity = "spell.fillOpacityCustom1_56",
				consoleVarOutlineOpacity = "spell.outlineOpacityCustom1_56",
				consoleVarColorR = "spell.custom1AllyBeneficialTelegraphColorR",
				consoleVarColorG = "spell.custom1AllyBeneficialTelegraphColorG",
				consoleVarColorB = "spell.custom1AllyBeneficialTelegraphColorB",
			},
			[5] =
			{
				bReadOnlyColors = false,
				consoleVarFillOpacity = "spell.fillOpacityCustom2_56",
				consoleVarOutlineOpacity = "spell.outlineOpacityCustom2_56",
				consoleVarColorR = "spell.custom2AllyBeneficialTelegraphColorR",
				consoleVarColorG = "spell.custom2AllyBeneficialTelegraphColorG",
				consoleVarColorB = "spell.custom2AllyBeneficialTelegraphColorB",
			}
		}
	},
	{
		strLabel = "Options_TelegraphColorAllyDetrimental",
		tSets =
		{
			[0] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityDefault_78",
				consoleVarOutlineOpacity = "spell.outlineOpacityDefault_78",
				crColor = ApolloColor.new(255.0/255.0, 152.0/255.0, 43.0/255.0)
			},
			[1] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityDeuteranopia_78",
				consoleVarOutlineOpacity = "spell.outlineOpacityDeuteranopia_78",
				crColor = ApolloColor.new(0.0/255.0, 170.0/255.0, 114.0/255.0)
			},
			[2] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityProtanopia_78",
				consoleVarOutlineOpacity = "spell.outlineOpacityProtanopia_78",
				crColor = ApolloColor.new(0.0/255.0, 179.0/255.0, 88.0/255.0)
			},
			[3] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityTritanopia_78",
				consoleVarOutlineOpacity = "spell.outlineOpacityTritanopia_78",
				crColor = ApolloColor.new(255.0/255.0, 225.0/255.0, 0.0/255.0)
			},
			[4] =
			{
				bReadOnlyColors = false,
				consoleVarFillOpacity = "spell.fillOpacityCustom1_78",
				consoleVarOutlineOpacity = "spell.outlineOpacityCustom1_78",
				consoleVarColorR = "spell.custom1AllyDetrimentalTelegraphColorR",
				consoleVarColorG = "spell.custom1AllyDetrimentalTelegraphColorG",
				consoleVarColorB = "spell.custom1AllyDetrimentalTelegraphColorB",
			},
			[5] =
			{
				bReadOnlyColors = false,
				consoleVarFillOpacity = "spell.fillOpacityCustom2_78",
				consoleVarOutlineOpacity = "spell.outlineOpacityCustom2_78",
				consoleVarColorR = "spell.custom2AllyDetrimentalTelegraphColorR",
				consoleVarColorG = "spell.custom2AllyDetrimentalTelegraphColorG",
				consoleVarColorB = "spell.custom2AllyDetrimentalTelegraphColorB",
			}
		}
	},
	{
		strLabel = "Options_TelegraphColorHarmless",
		tSets =
		{
			[0] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityDefault_12",
				consoleVarOutlineOpacity = "spell.outlineOpacityDefault_12",
				crColor = ApolloColor.new(168.0/255.0, 128.0/255.0, 128.0/255.0)
			},
			[1] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityDeuteranopia_12",
				consoleVarOutlineOpacity = "spell.outlineOpacityDeuteranopia_12",
				crColor = ApolloColor.new(168.0/255.0, 128.0/255.0, 128.0/255.0)
			},
			[2] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityProtanopia_12",
				consoleVarOutlineOpacity = "spell.outlineOpacityProtanopia_12",
				crColor = ApolloColor.new(168.0/255.0, 128.0/255.0, 128.0/255.0)
			},
			[3] =
			{
				bReadOnlyColors = true,
				consoleVarFillOpacity = "spell.fillOpacityTritanopia_12",
				consoleVarOutlineOpacity = "spell.outlineOpacityTritanopia_12",
				crColor = ApolloColor.new(168.0/255.0, 128.0/255.0, 128.0/255.0)
			},
			[4] =
			{
				bReadOnlyColors = false,
				consoleVarFillOpacity = "spell.fillOpacityCustom1_12",
				consoleVarOutlineOpacity = "spell.outlineOpacityCustom1_12",
				consoleVarColorR = "spell.custom1EnemyHarmlessDetrimentalTelegraphColorR",
				consoleVarColorG = "spell.custom1EnemyHarmlessDetrimentalTelegraphColorG",
				consoleVarColorB = "spell.custom1EnemyHarmlessDetrimentalTelegraphColorB",
			},
			[5] =
			{
				bReadOnlyColors = false,
				consoleVarFillOpacity = "spell.fillOpacityCustom2_12",
				consoleVarOutlineOpacity = "spell.outlineOpacityCustom2_12",
				consoleVarColorR = "spell.custom2EnemyHarmlessDetrimentalTelegraphColorR",
				consoleVarColorG = "spell.custom2EnemyHarmlessDetrimentalTelegraphColorG",
				consoleVarColorB = "spell.custom2EnemyHarmlessDetrimentalTelegraphColorB",
			}
		}
	},
}

function OptionsAddon:new(o)
	o = o or {}
	setmetatable(o, self)
	self.__index = self
	return o
end

function OptionsAddon:Init()
	Apollo.RegisterAddon(self)
end

function OptionsAddon:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("OptionsForms.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function OptionsAddon:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	Apollo.RegisterTimerHandler("ResChangedTimer", 		"OnResChangedTimer", self)
	Apollo.RegisterTimerHandler("ResExChangedTimer", 	"OnResExChangedTimer", self)
	Apollo.RegisterTimerHandler("AddonsUpdateTimer", 	"OnAddonsUpdateTimer", self)

	Apollo.RegisterEventHandler("SystemKeyDown", 		"OnSystemKeyDown", self)
	Apollo.RegisterEventHandler("TriggerDemoOptions", 	"OnInvokeOptionsScreen", self) --gamescom
	Apollo.RegisterEventHandler("EnteredCombat", 		"OnEnteredCombat", self)
	Apollo.RegisterEventHandler("RefreshOptionsDialog", "OnRefreshOptionsDialog", self)

	Apollo.CreateTimer("ResChangedTimer", 1.000, false)
	Apollo.StopTimer("ResChangedTimer")

	Apollo.CreateTimer("ResExChangedTimer", 1.000, false)
	Apollo.StopTimer("ResExChangedTimer")

	self.wndDemo = Apollo.LoadForm(self.xmlDoc, "DemoOptions", nil, self)
	self.wndDemo:Show(IsDemo())

	self.wndDemoGoodbye = Apollo.LoadForm(self.xmlDoc, "DemoSummary", nil, self)
	self.wndDemoGoodbye:Show(false)


	self.wndAddCoins = Apollo.LoadForm(self.xmlDoc, "DemoAddCoin", nil, self)
	self.wndAddCoins:Show(false)

	self.tAddons = {}
	self.nSortedBy = 0

	self.OptionsDlg = Apollo.LoadForm(self.xmlDoc, "OptionsMenu", nil, self)
	self.OptionsDlg:FindChild("ErrorIndicator"):Show(false)
	self.OptionsDlg:Show(not IsDemo())
	self.OptionsDlg:SetFocus()

	self.wndVideo = Apollo.LoadForm(self.xmlDoc, "VideoOptionsDialog", nil, self)
	Apollo.LoadForm(self.xmlDoc, "VideoOptionsControls", self.wndVideo:FindChild("ScrollPanel"), self)
	self.wndVideo:FindChild("ResolutionParent"):FindChild("Resolution"):Enable(true)
	self.wndVideo:FindChild("DropToggleExclusive"):AttachWindow(self.wndVideo:FindChild("ResolutionParent"))
	self.wndVideoConfirm = self.wndVideo:FindChild("TimedChangeBlocker")
	self.wndVideoConfirm:Show(false)

	self.wndRequiresRestartConfirm = self.wndVideo:FindChild("ChangeRestartBlocker")
	
	----

	self.wndSounds = Apollo.LoadForm(self.xmlDoc, "SoundOptionsDialog", nil, self)
	self.wndAddons = Apollo.LoadForm(self.xmlDoc, "AddonsDialog", nil, self)

	self.wndTargeting = Apollo.LoadForm(self.xmlDoc, "TargettingDialog", nil, self)
	Apollo.LoadForm(self.xmlDoc, "TargettingOptionsControls", self.wndTargeting:FindChild("GroupContainer:TargettingDialogControls"), self)
	
	self.wndSearchEditBox = self.wndAddons:FindChild("SearchEditBox")

	self.bAddonsTimerCreated = false
	self.OptionsDlg:SetRadioSel("OptionsGroup", 0)
	self:OnOptionsCheck()

	self.nDemoAutoTimeout = 0 -- TODO: more demo

	self.wndVideo:FindChild("VerticalSync"):AttachWindow(self.wndVideo:FindChild("VerticalSyncBLocker"))

	self.mapCB2CVs =  -- these are auto-mapped options than don't need custom handlers
	{
		{wnd = self.wndVideo:FindChild("VerticalSync"), 		consoleVar = "video.verticalSync",												requiresRestart = false},
		{wnd = self.wndVideo:FindChild("EnableCameraShake"), 	consoleVar = "camera.shake",													requiresRestart = false},
		{wnd = self.wndVideo:FindChild("EnableFixedCamera"), 	consoleVar = "camera.reorient",													requiresRestart = false},

		-- Combat
		{wnd = self.wndTargeting:FindChild("UseButtonDownBtn"), 				consoleVar = "spell.useButtonDownForAbilities",					requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("HoldToContinueCastingBtn"), 		consoleVar = "spell.holdToContinueCasting",						requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("MoveToBtn"), 						consoleVar = "player.moveToTargetOnSelfAOE",					requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("MoveActivateBtn"), 					consoleVar = "player.moveToActivate",							requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("StickyTargetingBtn"),				consoleVar = "player.stickyTargeting",							requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("ClickToMoveBtn"),					consoleVar = "player.clickToMove",								requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("AutoPushTarget"), 					consoleVar = "spell.disableAutoTargeting",						requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("DashDirectionalBtn"), 				consoleVar = "player.directionalDashBackward",					requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("SelfDisplayBtn"), 					consoleVar = "spell.selfTelegraphDisplay",						requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("EnemyDisplayBtn"), 					consoleVar = "spell.enemyTelegraphDisplay",						requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("EnemyNPCDisplayBtn"), 				consoleVar = "spell.enemyNPCTelegraphDisplay",					requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("EnemyNPCBeneficialDisplayBtn"), 	consoleVar = "spell.enemyNPCBeneficialTelegraphDisplay",			requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("EnemyNPCDetrimentalDisplayBtn"),	consoleVar = "spell.enemyNPCDetrimentalTelegraphDisplay",			requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("EnemyPlayerDisplayBtn"), 			consoleVar = "spell.enemyPlayerTelegraphDisplay",				requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("EnemyPlayerBeneficialDisplayBtn"), 	consoleVar = "spell.enemyPlayerBeneficialTelegraphDisplay",		requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("EnemyPlayerDetrimentalDisplayBtn"), consoleVar = "spell.enemyPlayerDetrimentalTelegraphDisplay",		requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("AllyDisplayBtn"), 					consoleVar = "spell.allyTelegraphDisplay",						requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("PartyAllyDisplayBtn"), 				consoleVar = "spell.partyMemberAllyTelegraphDisplay",			requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("AllyNPCDisplayBtn"), 				consoleVar = "spell.allyNPCTelegraphDisplay",					requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("AllyNPCBeneficialDisplayBtn"), 		consoleVar = "spell.allyNPCBeneficialTelegraphDisplay",			requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("AllyNPCDetrimentalDisplayBtn"), 	consoleVar = "spell.allyNPCDetrimentalTelegraphDisplay",			requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("AllyPlayerDisplayBtn"), 			consoleVar = "spell.allyPlayerTelegraphDisplay",				requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("AllyPlayerBeneficialDisplayBtn"), 	consoleVar = "spell.allyPlayerBeneficialTelegraphDisplay",		requiresRestart = false},
		{wnd = self.wndTargeting:FindChild("AllyPlayerDetrimentalDisplayBtn"), 	consoleVar = "spell.allyPlayerDetrimentalTelegraphDisplay",		requiresRestart = false},
	}

	self.mapSB2CVs =  -- these are auto-mapped sliders that don't need custom handlers
	{
		-- video options
		{wnd = self.wndVideo:FindChild("MaxFPSSlider"), 			consoleVar = "video.framerateMax",			buddy = self.wndVideo:FindChild("MaxFPSEditBox"),								requiresRestart = false},
		{wnd = self.wndVideo:FindChild("ViewDistanceSlider"), 		consoleVar = "lod.viewDistance",			buddy = self.wndVideo:FindChild("ViewDistanceEditBox"),							requiresRestart = false},
		{wnd = self.wndVideo:FindChild("VDFogSlider"), 				consoleVar = "lod.farFogDistance",			buddy = self.wndVideo:FindChild("VDFogEditBox"),								requiresRestart = false},
		{wnd = self.wndVideo:FindChild("ClutterDistanceSlider"), 	consoleVar = "lod.clutterDistance",			buddy = self.wndVideo:FindChild("ClutterDistanceEditBox"),						requiresRestart = false},
		{wnd = self.wndVideo:FindChild("CameraDistanceSlider"),		consoleVar = "camera.distanceMax",			buddy = self.wndVideo:FindChild("CameraDistanceEditBox"),						requiresRestart = false},
		{wnd = self.wndVideo:FindChild("FieldOfVisionSlider"),		consoleVar = "camera.fovY",					buddy = self.wndVideo:FindChild("FieldOfVisionEditBox"),						requiresRestart = false},
		{wnd = self.wndVideo:FindChild("GammaScaleSlider"),			consoleVar = "ppp.gamma",					buddy = self.wndVideo:FindChild("GammaScaleEditBox"), 			format = "%.02f",		requiresRestart = false},
		{wnd = self.wndVideo:FindChild("VisualSupressionSlider"),	consoleVar = "spell.visualSuppression",		buddy = self.wndVideo:FindChild("VisualSupressionEditBox"), 		format = "%.02f",		requiresRestart = false},

		-- audio options
		{wnd = self.wndSounds:FindChild("MasterVolumeSliderBar"), 	consoleVar = "sound.volumeMaster",		buddy = self.wndSounds:FindChild("MasterVolumeEditBox"), 		 format = "%.02f",		requiresRestart = false, bSoundSlider = true},
		{wnd = self.wndSounds:FindChild("MusicVolumeSliderBar"), 	consoleVar = "sound.volumeMusic",		buddy = self.wndSounds:FindChild("MusicVolumeEditBox"), 		 format = "%.02f",		requiresRestart = false, bSoundSlider = true},
		{wnd = self.wndSounds:FindChild("UIVolumeSliderBar"), 		consoleVar = "sound.volumeUI",			buddy = self.wndSounds:FindChild("UIVolumeEditBox"), 			 format = "%.02f",		requiresRestart = false, bSoundSlider = true},
		{wnd = self.wndSounds:FindChild("SoundFXVolumeSliderBar"), 	consoleVar = "sound.volumeSfx",			buddy = self.wndSounds:FindChild("SoundFXVolumeEditBox"), 		 format = "%.02f",		requiresRestart = false, bSoundSlider = true},
		{wnd = self.wndSounds:FindChild("AmbientVolumeSliderBar"), 	consoleVar = "sound.volumeAmbient",		buddy = self.wndSounds:FindChild("AmbientVolumeEditBox"), 		 format = "%.02f",		requiresRestart = false, bSoundSlider = true},
		{wnd = self.wndSounds:FindChild("VoiceVolumeSliderBar"), 	consoleVar = "sound.volumeVoice",		buddy = self.wndSounds:FindChild("VoiceVolumeEditBox"), 		 format = "%.02f",		requiresRestart = false, bSoundSlider = true},
	}

	self.mapDDParents =
	{
		-- video options
		{wnd = self.wndVideo:FindChild("DropToggleRenderTarget"),		consoleVar = "lod.renderTargetScale",				radio = "RenderTargetScale",		requiresRestart = false},
		{wnd = self.wndVideo:FindChild("DropToggleResolution"),			consoleVar = "video.fullscreen", 					radio = "ResolutionMode",			requiresRestart = false},
		{wnd = self.wndVideo:FindChild("DropToggleTexLOD"),				consoleVar = "lod.textureLodMin",					radio = "TextureResolution",		requiresRestart = false},
		{wnd = self.wndVideo:FindChild("DropToggleTexFilter"),			consoleVar = "lod.textureFilter", 					radio = "TextureFiltering",		requiresRestart = true},
		{wnd = self.wndVideo:FindChild("DropToggleFXAA"),				consoleVar = "fxaa.preset", 						radio = "FXAA",				requiresRestart = false},
		{wnd = self.wndVideo:FindChild("DropToggleClutterDensity"),		consoleVar = "lod.clutterDensity", 					radio = "ClutterDensity",			requiresRestart = false},
		{wnd = self.wndVideo:FindChild("DropToggleSceneDetail"),		consoleVar = "world.propScreenHeightPercentMin", 	radio = "SceneDetail",			requiresRestart = false},
		{wnd = self.wndVideo:FindChild("DropToggleLandLOD"),			consoleVar = "lod.landlod", 						radio = "LandLOD",				requiresRestart = false},
		{wnd = self.wndVideo:FindChild("DropToggleShadow"),				consoleVar = "draw.shadows", 						radio = "ShadowSetting",			requiresRestart = false},
		{wnd = self.wndVideo:FindChild("DropToggleParticleScale"),		consoleVar = "particle.envParticleScale", 			radio = "ParticleScale",			requiresRestart = false},
		{wnd = self.wndVideo:FindChild("DropToggleVisualSupression"),	consoleVar = "spell.visualSuppression", 			radio = "VisualSupression",		requiresRestart = false},
	}

	local wndDropToggleTelegraphPresetSettings = self.wndTargeting:FindChild("GroupContainer:TargettingDialogControls:TargettingOptionsControls:TelegraphOptionsFrame:TelelgraphColorsHeader:DropToggleTelegraphPresetSettings")
	wndDropToggleTelegraphPresetSettings:FindChild("ChoiceContainer:TelegraphPreset_Default"):SetData(0)
	wndDropToggleTelegraphPresetSettings:FindChild("TelegraphPreset_Deuteranopia"):SetData(1)
	wndDropToggleTelegraphPresetSettings:FindChild("TelegraphPreset_Protanopia"):SetData(2)
	wndDropToggleTelegraphPresetSettings:FindChild("TelegraphPreset_Tritanopia"):SetData(3)
	wndDropToggleTelegraphPresetSettings:FindChild("TelegraphPreset_Custom1"):SetData(4)
	wndDropToggleTelegraphPresetSettings:FindChild("TelegraphPreset_Custom2"):SetData(5)

	local wndDropToggleTelegraphPresetSettings = self.wndTargeting:FindChild("GroupContainer:TargettingDialogControls:TargettingOptionsControls:TelegraphOptionsFrame:TelelgraphColorsHeader:DropToggleTelegraphPresetSettings")
	wndDropToggleTelegraphPresetSettings:AttachWindow(wndDropToggleTelegraphPresetSettings:FindChild("ChoiceContainer"))

	local wndTelelgraphColors = self.wndTargeting:FindChild("GroupContainer:TargettingDialogControls:TargettingOptionsControls:TelegraphOptionsFrame:TelelgraphColors")
	for idx, tTelegraphColor in pairs(ktTelegraphColorOptions) do
		local wndTelegraphColor = Apollo.LoadForm(self.xmlDoc, "TelegraphColorLine", wndTelelgraphColors, self)
		local wndLabel = wndTelegraphColor:FindChild("Label")
		wndLabel:SetText(Apollo.GetString(tTelegraphColor.strLabel))

		local wndColorBtn = wndTelegraphColor:FindChild("ColorBtn")
		local wndTelegraphChoiceContainer = Apollo.LoadForm(self.xmlDoc, "TelegraphChoiceContainer", wndColorBtn, self)
		wndTelegraphChoiceContainer:SetData(tTelegraphColor)
		wndColorBtn:AttachWindow(wndTelegraphChoiceContainer)

		local wndR_EditBox = wndTelegraphChoiceContainer:FindChild("R_EditBox")
		wndR_EditBox:SetData("consoleVarColorR")

		local wndG_EditBox = wndTelegraphChoiceContainer:FindChild("G_EditBox")
		wndG_EditBox:SetData("consoleVarColorG")

		local wndB_EditBox = wndTelegraphChoiceContainer:FindChild("B_EditBox")
		wndB_EditBox:SetData("consoleVarColorB")
	end
	wndTelelgraphColors:ArrangeChildrenVert(0)

	for idx, wndDD in pairs(self.mapDDParents) do
		wndDD.wnd:AttachWindow(wndDD.wnd:FindChild("ChoiceContainer"))
		wndDD.wnd:FindChild("ChoiceContainer"):Show(false)
	end

	self.wndSounds:FindChild("CinematicSubtitles"):SetCheck(Apollo.GetConsoleVariable("draw.subtitles"))
	self.wndSounds:FindChild("CombatMusicFlair"):SetCheck(Apollo.GetConsoleVariable("sound.intenseBattleMusic"))
	self.wndSounds:FindChild("PlayInBackground"):SetCheck(Apollo.GetConsoleVariable("sound.playInBackground"))
	self.wndSounds:FindChild("Mute"):SetCheck(Apollo.GetConsoleVariable("sound.mute"))

	self.wndVideo:FindChild("DropTogglePresetSettings"):AttachWindow(self.wndVideo:FindChild("DropTogglePresetSettings"):FindChild("ChoiceContainer"))
	self.wndVideo:FindChild("DropTogglePresetSettings"):FindChild("ChoiceContainer"):Show(false)

	for strPreset, tPreset in pairs(ktVideoSettingLevels) do
		self.wndVideo:FindChild("DropTogglePresetSettings"):FindChild(strPreset):SetData(self.wndVideo:FindChild("DropTogglePresetSettings"))
	end
	self.wndVideo:FindChild("DropTogglePresetSettings"):FindChild("Custom"):SetData(self.wndVideo:FindChild("DropTogglePresetSettings"))

	self.tPrevExcRes = nil
	self.tPrevResSettings = nil

	-- TODO REMOVE
	local bPlayerSetting = Apollo.GetConsoleVariable("player.showDoubleTapToDash")
	Apollo.SetConsoleVariable("player.doubleTapToDash", bPlayerSetting) -- these should match

	self:InitOptionsControls()

	self.bReachedTheEnd = false
	self.pathMissionCount = 1
	self.pathMissionCompleted = 1

	if not self.bAddonsTimerCreated and not IsDemo() then
		Apollo.CreateTimer("AddonsUpdateTimer", 1.0, true)
		self.bAddonsTimerCreated = true
	end

	local tDisplayMode = Apollo.GetConsoleVariable("video.exclusiveDisplayMode")
	if tDisplayMode.x == 0 and tDisplayMode.y == 0 and tDisplayMode.z == 0 then --no console variable data
		local arModes = EnumerateDisplayModes()
		local tModeDisplay
		for i, tMode in ipairs(arModes) do
			if tMode.bCurrent then
				tModeDisplay = tMode
				break
			end
		end

		Apollo.SetConsoleVariable("video.exclusiveDisplayMode", tModeDisplay.vec)
		self.wndVideo:FindChild("DropToggleExclusive"):Enable(Apollo.GetConsoleVariable("video.exclusive"))
	end
	
	
	if not Is64BitClient() then
		self.wndVideo:FindChild("ViewDistanceSlider"):SetMinMax(256, 512, 4)
		local wndTextureResolutionChoiceContainer = self.wndVideo:FindChild("ScrollPanel:VideoOptionsControls:RenderQualityFrame:TextureLOD:DropToggleTexLOD:ChoiceContainer")
		local wndTextureResolutionHigh = wndTextureResolutionChoiceContainer:FindChild("TextureResolutionHigh")
		wndTextureResolutionHigh:Show(false)
		local nLeft, nTop, nRight, nBottom = wndTextureResolutionChoiceContainer:GetAnchorOffsets()
		wndTextureResolutionChoiceContainer:SetAnchorOffsets(nLeft, nTop, nRight, nBottom - wndTextureResolutionHigh:GetHeight())
	end
end

---------------------------------------------------------------------------------------------------
-- Functions
---------------------------------------------------------------------------------------------------

function OptionsAddon:OnSearchEditBoxChanged(wndHandler, wndControl, strText)
	if wndHandler ~= wndControl then
		return
	end

	wndClearBtn = self.wndAddons:FindChild("SearchClearBtn")
	wndSearchIcon = self.wndAddons:FindChild("SearchIcon")
	if wndClearBtn and wndSearchIcon then
		wndClearBtn:Show(strText ~= "")
		wndSearchIcon:Show(not strText ~= "")
	end
	
	local wndGrid = self.wndAddons:FindChild("AddonGrid")
	if wndGrid then
		wndGrid:DeleteAll()
	end
	
	if strText == "" then
		self:ResetAddonGrid()
	else
		for idx, tAddon in ipairs(self.tAddons) do
			local strAddonNameSubString = string.sub(tAddon.strName, 1 ,  string.len(strText))
			if Apollo.StringToLower(strAddonNameSubString) == Apollo.StringToLower(strText) then
				self:HelperAddToGrid(wndGrid, tAddon)
			end
		end
	end
end

function OptionsAddon:OnSearchClearBtn(wndHandler, wndControl)
	if wndHandler ~= wndControl then
		return
	end

	self.wndSearchEditBox:SetText("")
	wndHandler:Show(false)
	self:ResetAddonGrid()
end

function OptionsAddon:ResetAddonGrid()
	local wndGrid = self.wndAddons:FindChild("AddonGrid")
	if not wndGrid or not self.tAddons then
		return
	end

	wndGrid:DeleteAll()
	for idx, tAddon in ipairs(self.tAddons) do
		self:HelperAddToGrid(wndGrid, tAddon)
	end
end

function OptionsAddon:HelperAddToGrid(wndGrid, tAddon)
	local nRow = wndGrid:AddRow(tAddon.strName)
	wndGrid:SetCellLuaData(nRow, EnumAddonColumns.Name, tAddon.strName)
	self:UpdateAddonGridRow(wndGrid, nRow, tAddon)
end

function OptionsAddon:OnRefreshOptionsDialog()
	if self.OptionsDlg:IsShown() then
		self:OnOptionsCheck()
	end
end

function OptionsAddon:OnOptionsCheck()
	self:InitOptionsControls()

	local nOptions = self.OptionsDlg:FindChild("InnerFrame"):GetRadioSel("OptionsGroup")
	self.wndVideo:Show(nOptions == 1)
	self.wndSounds:Show(nOptions == 2)
	self.wndAddons:Show(nOptions == 3 and IsInGame())
	self.wndTargeting:Show(nOptions == 4)

	if nOptions ~= 1 and self.nOptionsTimer ~= 0 then -- unsaved graphic change
		self:OnChangeCancelBtn()
	end

	if nOptions == 1 then
		self.wndVideo:SetAnchorOffsets(self.wndVideo:GetAnchorOffsets())
		self:EnableVideoControls()
	elseif nOptions == 2 then
		self.wndSounds:SetAnchorOffsets(self.wndSounds:GetAnchorOffsets())
		self.wndSounds:FindChild("CombatMusicFlair"):SetCheck(Apollo.GetConsoleVariable("sound.intenseBattleMusic"))
		self.wndSounds:FindChild("CinematicSubtitles"):SetCheck(Apollo.GetConsoleVariable("draw.subtitles"))
		self.wndSounds:FindChild("PlayInBackground"):SetCheck(Apollo.GetConsoleVariable("sound.playInBackground"))
	elseif nOptions == 3 then
		self.wndAddons:SetAnchorOffsets(self.wndAddons:GetAnchorOffsets())
		self:OnAddonsCheck(true)
	elseif nOptions == 4 then
		self:InitTargetingControls()
		self:OnMappedOptionsCheckboxHider()
		self.wndTargeting:SetAnchorOffsets(self.wndTargeting:GetAnchorOffsets())
		self:EnableTelegraphColorControls()
	end
end

function OptionsAddon:InitTargetingControls()
	self.wndTargeting:FindChild("DashDoubleTapBtn"):SetCheck(Apollo.GetConsoleVariable("player.showDoubleTapToDash"))
	self.wndTargeting:FindChild("UseAbilityQueueBtn"):SetCheck(Apollo.GetConsoleVariable("player.abilityQueueMax") > 0)

	self.wndTargeting:FindChild("AbilityQueueLengthBlocker"):Show(Apollo.GetConsoleVariable("player.abilityQueueMax") == 0)
	self.wndTargeting:FindChild("AbilityQueueLengthSliderBar"):SetValue(Apollo.GetConsoleVariable("player.abilityQueueMax") or 0)
	self.wndTargeting:FindChild("MouseTurnSpeedSliderBar"):SetValue(Apollo.GetConsoleVariable("player.turningSpeedMouse") or 0)
	self.wndTargeting:FindChild("KeyboardTurnSpeedSliderBar"):SetValue(Apollo.GetConsoleVariable("player.turningSpeedKeyboard") or 0)
	self.wndTargeting:FindChild("AbilityQueueLengthEditBox"):SetText(string.format("%.0f", Apollo.GetConsoleVariable("player.abilityQueueMax")))
	self.wndTargeting:FindChild("MouseTurnSpeedEditBox"):SetText(string.format("%.2f", Apollo.GetConsoleVariable("player.turningSpeedMouse")))
	self.wndTargeting:FindChild("KeyboardTurnSpeedEditBox"):SetText(string.format("%.2f", Apollo.GetConsoleVariable("player.turningSpeedKeyboard")))

	self.wndTargeting:FindChild("AlwaysFaceBtn"):SetCheck(not Apollo.GetConsoleVariable("Player.ignoreAlwaysFaceTarget"))
	self.wndTargeting:FindChild("FacingLockBtn"):Enable(self.wndTargeting:FindChild("AlwaysFaceBtn"):IsChecked())


end

---------------------------------------------------------------------------------------------------
-- AddonsDialog Functions
---------------------------------------------------------------------------------------------------

function SortConfigButtons(wnd1, wnd2)
	local str1 = ""
	local str2 = ""

	if wnd1 ~= nil and wnd1:FindChild("ConfigureAddonBtn") ~= nil then
		str1 = wnd1:FindChild("ConfigureAddonBtn"):GetText()
	end
	if wnd2 ~= nil and wnd2:FindChild("ConfigureAddonBtn") ~= nil then
		str2 = wnd2:FindChild("ConfigureAddonBtn"):GetText()
	end
	return str1 < str2
end

function OptionsAddon:FillConfigureList()
	self:GetAddonsList()
	local wndList = self.OptionsDlg:FindChild("ConfigureList")

	if self.tConfigureButtons == nil then
		self.tConfigureButtons = {}
	end

	-- copy all existing addons into kill list
	local tKill = {}
	for k, v in pairs(self.tConfigureButtons) do
		tKill[k] = v
	end

	for i, tAddon in ipairs(self.tAddons) do
		if tAddon.bHasConfigure then
			if self.tConfigureButtons[tAddon.strName] == nil then
				local wndConf = Apollo.LoadForm(self.xmlDoc, "ConfigureAddonItem", wndList, self)
				wndConf:FindChild("ConfigureAddonBtn"):SetText(tAddon.strConfigureButtonText)
				wndConf:FindChild("ConfigureAddonBtn"):SetData(tAddon.strName)
				self.tConfigureButtons[tAddon.strName] = wndConf
			else
				self.tConfigureButtons[tAddon.strName]:FindChild("ConfigureAddonBtn"):SetText(tAddon.strConfigureButtonText)
			end
			-- remove the addon from the kill list
			tKill[tAddon.strName] = nil
		end
	end

	-- if any items remain in kill list, destroy them because we the addon has disappeared
	for k, wnd in pairs(tKill) do
		wnd:Destroy()
		self.tConfigureButtons[k] = nil
	end

	wndList:ArrangeChildrenVert(0, SortConfigButtons)
end

function OptionsAddon:UpdateAddonInfo(tAddon)
	tAddon.strStatus = Apollo.GetString(karStatusText[tAddon.eStatus])

	if tAddon.bCarbine then
		tAddon.strAuthor = Apollo.GetString("Options_AuthorCarbine")
	else
		tAddon.strAuthor = Apollo.GetString("Options_AuthorUnknown") -- this is temporary until the real info is passed from the client
	end
end

function OptionsAddon:GetAddonsList()
	self.tAddons = GetAddons()

	for idx, tAddon in ipairs(self.tAddons) do
		self:UpdateAddonInfo(tAddon)
	end
end

function OptionsAddon:UpdateAddonGridRow(wndGrid, nRow, tAddon)
	wndGrid:SetCellLuaData(nRow, EnumAddonColumns.Name, tAddon.strName)
	wndGrid:SetCellText(nRow, EnumAddonColumns.Name, tAddon.strName)
	wndGrid:SetCellText(nRow, EnumAddonColumns.Folder, tAddon.strName)
	wndGrid:SetCellText(nRow, EnumAddonColumns.Author, tAddon.strAuthor)
	wndGrid:SetCellText(nRow, EnumAddonColumns.APIVersion, tostring(tAddon.nAPIVersion))

	local strReplace = ""
	for idx, strAddon in ipairs(tAddon.arReplacedAddons) do
		if string.len(strReplace) > 0 then
			strReplace = String_GetWeaselString(Apollo.GetString("Archive_TextList"), strReplace, strAddon)
		else
			strReplace = strAddon
		end
	end
	wndGrid:SetCellText(nRow, EnumAddonColumns.Replaces, strReplace)

	local fTotalTime 	= tAddon.fTotalTime or 0.0
	local nTotalCalls 	= tAddon.nTotalCalls or 0
	local strTotalCalls = string.format("%5d", nTotalCalls)
	local fLongest 		= tAddon.fLongestCall or 0.0
	local strKb 		= string.format("%10.2fKb", tAddon.nMemoryUsage / 1024)
	local strTotalTime 	= string.format("%10.3fs", fTotalTime)
	local strLongest 	= string.format("%10.3fs", fLongest)
	local strMsPerFrame = string.format("%10.3fms", tAddon.fCallTimePerFrame * 1000.0)
	local strStatus 	= Apollo.GetString(karStatusTextString[tAddon.eStatus])

	wndGrid:SetCellText(nRow, EnumAddonColumns.Memory, strKb)
	wndGrid:SetCellText(nRow, EnumAddonColumns.Calls, strTotalCalls)
	wndGrid:SetCellText(nRow, EnumAddonColumns.TotalTime, strTotalTime)
	wndGrid:SetCellText(nRow, EnumAddonColumns.MaxTime, strLongest)
	wndGrid:SetCellText(nRow, EnumAddonColumns.MsPerFrame, strMsPerFrame)
	wndGrid:SetCellText(nRow, EnumAddonColumns.Status, strStatus)
	wndGrid:SetCellImage(nRow, EnumAddonColumns.Status, "CRB_MinimapSprites:sprMMIndicator")
	wndGrid:SetCellImageColor(nRow, EnumAddonColumns.Status, karStatusColors[tAddon.eStatus])

	local strLoad = Apollo.GetString("CRB_No")
	if WillAddonLoad(tAddon.strName) then
		strLoad = Apollo.GetString("CRB_Yes")
	end
	wndGrid:SetCellText(nRow, EnumAddonColumns.LoadSetting, strLoad)
	wndGrid:SetCellText(nRow, EnumAddonColumns.LastModified, tAddon.strLastModified)
	wndGrid:SetCellSortText(nRow, EnumAddonColumns.Status, karSortingConstants[tAddon.eStatus]..tAddon.strName)
end

function OptionsAddon:OnAddonsCheck(bReload)
	if bReload or self.tAddons == nil then
		self:GetAddonsList()
		self.wndAddons:FindChild("LoadSettings"):Enable(false)
		self.wndAddons:FindChild("ShowError"):Enable(false)
		self.wndAddons:FindChild("Configure"):Enable(false)
	end

	if self.wndErrorDetail ~= nil then
		self.wndErrorDetail:Destroy()
		self.wndErrorDetail = nil
	end
	if self.wndLoadConditions ~= nil then
		self.wndLoadConditions:Destroy()
		self.wndLoadConditions = nil
	end

	local wndGrid = self.wndAddons:FindChild("AddonGrid")
	local nPos = wndGrid:GetVScrollPos()
	local nSortCol = wndGrid:GetSortColumn() or 1
	local bAscending = wndGrid:IsSortAscending()

	wndGrid:DeleteAll()
	--Check for Filter Results!
	self:OnSearchEditBoxChanged(self.wndSearchEditBox, self.wndSearchEditBox, self.wndSearchEditBox:GetText())
	wndGrid:SetSortColumn(nSortCol, bAscending)
	wndGrid:SetVScrollPos(nPos)
end

function OptionsAddon:OnAddonsUpdateTimer()
	if not IsScreenVisible() then
		return
	end

	self:FillConfigureList()
	self.OptionsDlg:FindChild("Camp"):Enable(IsInGame())
	self.OptionsDlg:FindChild("Stuck"):Enable(IsInGame())

	self.wndAddons:FindChild("GlobalIgnoreVersionMismatch"):SetCheck(GetGlobalAddonIgnoreVersion())

	if IsInCombat() then
		self.OptionsDlg:FindChild("OptionsLabel"):SetTextColor(CColor.new(1, 0, 0, 1))
	else
		self.OptionsDlg:FindChild("OptionsLabel"):SetTextColor(CColor.new(1, 1, 1, 1))
	end

	-- TODO: this logic got borked at some point (addition of the timer?) and the highlight is always shown. Need to investigate.
	if self.wndAddons:IsVisible() then
		local wndGrid = self.wndAddons:FindChild("AddonGrid")
		local arRowsToRemove = {}
		local bHighlightReloadButton = false
		for iRow = 1, wndGrid:GetRowCount() do
			local tNewInfo = GetAddonInfo(wndGrid:GetCellData(iRow, 2))
			if tNewInfo == nil then
				arRowsToRemove[#arRowsToRemove + 1] = iRow
			else
				self:UpdateAddonGridRow(wndGrid, iRow, tNewInfo)

				if (WillAddonLoad(tNewInfo.strName) and tNewInfo.eStatus <= OptionsScreen.CodeEnumAddonStatus.ParsingError)
					or (not WillAddonLoad(tNewInfo.strName) and tNewInfo.eStatus >= OptionsScreen.CodeEnumAddonStatus.Loaded) then
					bHighlightReloadButton = true
				end
			end
		end
		if bHighlightReloadButton then
			--self.wndAddons:FindChild("ReloadUI"):ChangeArt("CRB_UIKitSprites:btn_square_LARGE_Green")
			self.wndAddons:FindChild("ClickReloadPrompt"):Show(true)
		else
			--self.wndAddons:FindChild("ReloadUI"):ChangeArt("CRB_UIKitSprites:btn_square_LARGE_Red")
			self.wndAddons:FindChild("ClickReloadPrompt"):Show(false)
		end

		for iRow = 1, #arRowsToRemove do
			--wndGrid:DeleteRow(arRowsToRemove[iRow])
			-- TODO TEMP disabled for now
		end
	end
end


function OptionsAddon:OnShowErrors(wndHandler, wndControl)

	if self.strSelectedAddon == nil then
		return
	end

	local tAddon = GetAddonInfo(self.strSelectedAddon)
	if tAddon == nil then
		return
	end

	if self.wndErrorDetail ~= nil then
		self.wndErrorDetail:Destroy()
		self.wndErrorDetail = nil
	end

	local wnd = Apollo.LoadForm("OptionsForms.xml", "AddonError", "OptionsDialogs", self)

	local strError = ""
	for i, str in ipairs(tAddon.arErrors) do
		strError = strError .. str .. "\r\n\r\n"
	end

	wnd:FindChild("ErrorText"):SetText(strError)
	wnd:FindChild("Button1"):SetActionData(OptionsScreen.CodeEnumConfirmButtonType.CopyToClipboard, strError)
	wnd:ToFront()
	self.wndErrorDetail = wnd
end

function OptionsAddon:OnCloseErrorWindow(wndHandler, wndControl)
	wndHandler:GetParent():Destroy()
end

function OptionsAddon:InvokeAddonLoadOnStartDlg(tAddon)
	-- TEMPORARY SOLUTION FOR FX-68822
	if not tAddon or tAddon.strName == "EscapeMenu" then
		return
	end

	if self.wndLoadConditions ~= nil then
		self.wndLoadConditions:Destroy()
		self.wndLoadConditions = nil
	end

	local wnd = Apollo.LoadForm("OptionsForms.xml", "AddonLoadOptions", "OptionsDialogs", self)

	self.wndLoadConditions = wnd
	wnd:SetData(tAddon.strName)
	self:UpdateAddonLoadSetting(wnd)

	local mapLoadSettingToRadio = {
		[OptionsScreen.CodeEnumLoadType.Default] = 3,
		[OptionsScreen.CodeEnumLoadType.Yes] = 1,
		[OptionsScreen.CodeEnumLoadType.No] = 2,
	}

	local tInfo = GetAccountRealmCharacter()
	wnd:FindChild("Character"):SetText(tInfo.strCharacter)
	wnd:FindChild("Realm"):SetText(tInfo.strRealm)
	wnd:FindChild("Account"):SetText(tInfo.strAccount)

	wnd:FindChild("OptionsFrame"):SetRadioSel("MachineLoad", mapLoadSettingToRadio[tAddon.arLoadConditions[OptionsScreen.CodeEnumLoadLevel.Machine]])
	wnd:FindChild("AdvancedAddonOptions"):SetRadioSel("AccountLoad", mapLoadSettingToRadio[tAddon.arLoadConditions[OptionsScreen.CodeEnumLoadLevel.Account]])
	wnd:FindChild("AdvancedAddonOptions"):SetRadioSel("RealmLoad", mapLoadSettingToRadio[tAddon.arLoadConditions[OptionsScreen.CodeEnumLoadLevel.Realm]])
	wnd:FindChild("AdvancedAddonOptions"):SetRadioSel("CharacterLoad", mapLoadSettingToRadio[tAddon.arLoadConditions[OptionsScreen.CodeEnumLoadLevel.Character]])
	wnd:FindChild("OptionsFrame"):FindChild("IgnoreVersionMismatch"):SetCheck(tAddon.bIgnoreVersion)

	--SetAddonLoadOnStart(tAddon.strName, wndHandler:IsChecked())
end

function OptionsAddon:OnSetToDefault()
	self.wndAddons:FindChild("ConfirmationOverlay"):Show(true)
end

function OptionsAddon:OnSetToDefaultConfirm()
	self:HelperUncheckAllInnerFrame()
	ResetToDefaultAddons()
	self.wndAddons:FindChild("ConfirmationOverlay"):Show(false)
end

function OptionsAddon:OnCloseCancel()
	self.wndAddons:FindChild("ConfirmationOverlay"):Show(false)
end

function OptionsAddon:HelperUncheckAllInnerFrame()
	self.OptionsDlg:FindChild("VideoBtn"):SetCheck(false)
	self.OptionsDlg:FindChild("SoundBtn"):SetCheck(false)
	self.OptionsDlg:FindChild("ExitGame"):SetCheck(false)
	self.OptionsDlg:FindChild("AddonsBtn"):SetCheck(false)
	self.OptionsDlg:FindChild("TargetingBtn"):SetCheck(false)

	self.wndVideo:Show(false)
	self.wndSounds:Show(false)
	self.wndAddons:Show(false)
	self.wndTargeting:Show(false)
end

local g_mapRadioToLoadSetting = {
	OptionsScreen.CodeEnumLoadType.Yes,
	OptionsScreen.CodeEnumLoadType.No,
	OptionsScreen.CodeEnumLoadType.Default,
}

function OptionsAddon:UpdateAddonLoadSetting(wnd)
	local tAddon = GetAddonInfo(wnd:GetData())
	local str = tAddon.strName
	if WillAddonLoad(tAddon.strName) then
		str = String_GetWeaselString(Apollo.GetString("Options_WillLoad"), str)
	else
		str = String_GetWeaselString(Apollo.GetString("Options_WillNotLoad"), str)
	end
	wnd:FindChild("AddonTitle"):SetText(str)

	local nAPIVersion = Apollo.GetAPIVersion()
	local str = String_GetWeaselString(Apollo.GetString("Options_APICheck"), nAPIVersion, tAddon.nAPIVersion)
	wnd:FindChild("VersionMatchInformation"):SetText(str)
	if nAPIVersion == tAddon.nAPIVersion then
		wnd:FindChild("VersionMatchInformation"):SetTextColor(CColor.new(1, 1, 1, 1))
	else
		wnd:FindChild("VersionMatchInformation"):SetTextColor(CColor.new(1, 0, 0, 1))
	end
end

function OptionsAddon:OnIgnoreVersionMismatchCheck(wndHandler, wndControl, eMouseButton)
end

function OptionsAddon:OnChangeMachineLoad(wndHandler, wndControl, eMouseButton)
	local wndAddon = wndHandler:GetParent():GetParent()
	local tAddon = GetAddonInfo(wndAddon:GetData())

	local nRadio = wndHandler:GetParent():GetRadioSel("MachineLoad")
	SetAddonLoadCondition(tAddon.strName, OptionsScreen.CodeEnumLoadLevel.Machine, g_mapRadioToLoadSetting[nRadio])
	self:UpdateAddonLoadSetting(wndAddon)
end

function OptionsAddon:OnChangeAccountLoad(wndHandler, wndControl, eMouseButton)
	local wndAddon = wndHandler:GetParent():GetParent()
	local tAddon = GetAddonInfo(wndAddon:GetData())

	local nRadio = wndHandler:GetParent():GetRadioSel("AccountLoad")
	SetAddonLoadCondition(tAddon.strName, OptionsScreen.CodeEnumLoadLevel.Account, g_mapRadioToLoadSetting[nRadio])
	self:UpdateAddonLoadSetting(wndAddon)
end

function OptionsAddon:OnChangeRealmLoad(wndHandler, wndControl, eMouseButton)
	local wndAddon = wndHandler:GetParent():GetParent()
	local tAddon = GetAddonInfo(wndAddon:GetData())

	local nRadio = wndHandler:GetParent():GetRadioSel("RealmLoad")
	SetAddonLoadCondition(tAddon.strName, OptionsScreen.CodeEnumLoadLevel.Realm, g_mapRadioToLoadSetting[nRadio])
	self:UpdateAddonLoadSetting(wndAddon)
end

function OptionsAddon:OnChangeCharacterLoad(wndHandler, wndControl, eMouseButton)
	local wndAddon = wndHandler:GetParent():GetParent()
	local tAddon = GetAddonInfo(wndAddon:GetData())

	local nRadio = wndHandler:GetParent():GetRadioSel("CharacterLoad")
	SetAddonLoadCondition(tAddon.strName, OptionsScreen.CodeEnumLoadLevel.Character, g_mapRadioToLoadSetting[nRadio])
	self:UpdateAddonLoadSetting(wndAddon)
end

function OptionsAddon:OnEnableAddonCheck(wndHandler, wndControl, eMouseButton)
	local wndAddon = wndHandler:GetParent():GetParent()
	local tAddon = GetAddonInfo(wndAddon:GetData())
	self:UpdateAddonLoadSetting(wndAddon)
end

function OptionsAddon:OnAddonShowAdvancedToggle(wndHandler, wndControl)
	if wndHandler:IsChecked() then
		wndHandler:GetParent():FindChild("AdvancedAddonOptions"):Show(true)
		wndControl:SetText(Apollo.GetString("Options_HideAdvancedOptions"))
	else
		wndHandler:GetParent():FindChild("AdvancedAddonOptions"):Show(false)
		wndControl:SetText(Apollo.GetString("Options_ShowAdvancedOptions"))
	end
end

function OptionsAddon:OnCloseAddonWindow(wndHandler, wndControl, eMouseButton)
	wndHandler:GetParent():Destroy()
end

function OptionsAddon:OnIgnoreVersionMismatchCheck(wndHandler, wndControl, eMouseButton)
	local bChecked = wndHandler:IsChecked()
	local wndAddon = wndHandler:GetParent():GetParent()
	local tAddon = GetAddonInfo(wndAddon:GetData())
	SetAddonIgnoreVersion(tAddon.strName, bChecked)
	self:UpdateAddonLoadSetting(wndAddon)
end

function OptionsAddon:OnChangeLoadSettings(wndHandler, wndControl, eMouseButton)
	if self.strSelectedAddon == nil then
		return
	end

	-- TEMPORARY SOLUTION FOR FX-68822
	if self.strSelectedAddon == "EscapeMenu" then
		return
	end

	local tAddon = GetAddonInfo(self.strSelectedAddon)

	if tAddon then
		self:InvokeAddonLoadOnStartDlg(tAddon)
	end
end

function OptionsAddon:OnAddonSelChanged(wndHandler, wndControl, nRow, nCol)

	self.strSelectedAddon = wndControl:GetCellData(nRow, 2)
	-- TEMPORARY SOLUTION FOR FX-68822
	self.wndAddons:FindChild("LoadSettings"):Enable(self.strSelectedAddon ~= nil and self.strSelectedAddon ~= "EscapeMenu")

	local bShowErrorsButton = false
	local bShowConfigureButton = false
	if self.strSelectedAddon ~= nil then
		local tAddon = GetAddonInfo(self.strSelectedAddon)
		if tAddon ~= nil and #tAddon.arErrors > 0 then
			bShowErrorsButton = true
		end
		if tAddon ~= nil and tAddon.bHasConfigure and tAddon.eStatus >= OptionsScreen.CodeEnumAddonStatus.RunningWithError then
			bShowConfigureButton = true
		end
	end

	self.wndAddons:FindChild("ShowError"):Enable(bShowErrorsButton)
	self.wndAddons:FindChild("Configure"):Enable(bShowConfigureButton)
end

function OptionsAddon:OnAddonDoubleClick(wndHandler, wndControl, nRow, nCol)
	if nRow <= 0 then
		return
	end

	self.strSelectedAddon = wndControl:GetCellData(nRow, 2)
	local tAddon = GetAddonInfo(self.strSelectedAddon)
	if tAddon ~= nil then
		self:InvokeAddonLoadOnStartDlg(tAddon)
	end
end

function OptionsAddon:OnConfigure(wndHandler, wndControl, eMouseButton)
	CallConfigure(self.strSelectedAddon)
end

function OptionsAddon:OnConfigureAddon(wndHandler, wndControl, eMouseButton)
	CallConfigure(wndControl:GetData())
end

function OptionsAddon:OnIgnoreVersionMismatch( wndHandler, wndControl, eMouseButton )
	SetGlobalAddonIgnoreVersion(wndControl:IsChecked())
end

---------------------------------------------------------------------------------------------------
-- End Addons Management functions
---------------------------------------------------------------------------------------------------

function OptionsAddon:OnSystemKeyDown(iKey)
	if iKey == 27 then
		if not IsDemo() or GetDemoTimeRemaining() > 0 then
			self:OnOptionsClose()
		end
	end
	if iKey == 13 then
		--self:OnShowPassword()
	end
end

function OptionsAddon:OnOptionsClose()
	if self.nOptionsTimer ~= 0 then -- unsaved graphic change
		self:OnChangeCancelBtn()
	end

	self.wndTargeting:Show(false) -- TODO Hack for F&F: We hide the window to force a button click to bring it back up (as there's some state initialization there)
	--self.OptionsDlg:FindChild("InnerFrame"):FindChild("TargetingBtn"):SetCheck(false)
	self.wndAddons:FindChild("ConfirmationOverlay"):Show(false)
	CloseOptions()
end

function OptionsAddon:OnExitGame()
	ExitGame()
end

function OptionsAddon:OnRequestCamp( wndHandler, wndControl, eMouseButton )
	RequestCamp()
end

function OptionsAddon:InitOptionsControls()
	self.wndVideoConfirm:Show(false)

	self:RefreshPresetVideoSelection()

	for idx, mapping in pairs(self.mapCB2CVs or {}) do
		if mapping.wnd then
			mapping.wnd:SetCheck(Apollo.GetConsoleVariable(mapping.consoleVar))
			mapping.wnd:SetData(mapping)
		end
	end

	local bMute = Apollo.GetConsoleVariable("sound.mute")
	for idx, mapping in pairs(self.mapSB2CVs or {}) do
		if mapping.wnd ~= nil then
			if type(mapping.consoleVar) == "table" then
				mapping.wnd:SetValue(Apollo.GetConsoleVariable(mapping.consoleVar[1]))
			else
				local nValue =  Apollo.GetConsoleVariable(mapping.consoleVar)
				if mapping.bSoundSlider and bMute then
					nValue = 0
				end
				mapping.wnd:SetValue(nValue)
			end

			mapping.wnd:SetData(mapping)
			if mapping.buddy ~= nil then
				local strFormat = "%s"
				if mapping.format ~= nil then
					strFormat = mapping.format
				end

				if type(mapping.consoleVar) == "table" then
					mapping.buddy:SetText(string.format(strFormat, Apollo.GetConsoleVariable(mapping.consoleVar[1])))
				else
					local nValue =  Apollo.GetConsoleVariable(mapping.consoleVar)
					if mapping.bSoundSlider and bMute then
						nValue = 0
					end
					
					mapping.buddy:SetText(string.format(strFormat, nValue))
				end
			end
			
			local wndBlocker = mapping.wnd:GetParent():FindChild("SliderBlocker")
			if mapping.bSoundSlider and wndBlocker then
				wndBlocker:Show(bMute)
				mapping.wnd:Enable(not bMute)
				self.wndSounds:FindChild("PlayInBackground"):Enable(not bMute)
			end
		end
	end

	for idx, parent in pairs(self.mapDDParents or {}) do
		if parent.wnd ~= nil and parent.consoleVar ~= nil and parent.radio ~= nil then
			local arBtns = parent.wnd:FindChild("ChoiceContainer"):GetChildren()
			for idxBtn = 1, #arBtns do
				arBtns[idxBtn]:SetCheck(false)
			end

			if parent.consoleVar == "video.fullscreen" then
				if Apollo.GetConsoleVariable("video.fullscreen") == true then
					if Apollo.GetConsoleVariable("video.exclusive") == true then
						self.wndVideo:SetRadioSel(parent.radio, 3)
						arBtns[3]:SetCheck(true)
						parent.wnd:SetText(arBtns[3]:GetText())
					else
						self.wndVideo:SetRadioSel(parent.radio, 2)
						arBtns[2]:SetCheck(true)
						parent.wnd:SetText(arBtns[2]:GetText())
					end
				else
					self.wndVideo:SetRadioSel(parent.radio, 1)
					arBtns[1]:SetCheck(true)
					parent.wnd:SetText(arBtns[1]:GetText())
				end
			elseif parent.consoleVar == "lod.renderTargetScale" then
				if Apollo.GetConsoleVariable("lod.renderTargetScale") == 1 then
					self.wndVideo:SetRadioSel(parent.radio, 1)
					arBtns[1]:SetCheck(true)
				elseif Apollo.GetConsoleVariable("lod.renderTargetScale") == 0.75 then
					self.wndVideo:SetRadioSel(parent.radio, 2)
					arBtns[2]:SetCheck(true)
				else
					self.wndVideo:SetRadioSel(parent.radio, 3)
					arBtns[3]:SetCheck(true)
				end
			elseif parent.consoleVar == "fxaa.preset" then
				if Apollo.GetConsoleVariable("fxaa.preset") == 5 then
					self.wndVideo:SetRadioSel(parent.radio, 1)
					arBtns[1]:SetCheck(true)
				elseif Apollo.GetConsoleVariable("fxaa.preset") == 4 then
					self.wndVideo:SetRadioSel(parent.radio, 2)
					arBtns[2]:SetCheck(true)
				elseif Apollo.GetConsoleVariable("fxaa.preset") == 3 then
					self.wndVideo:SetRadioSel(parent.radio, 3)
					arBtns[3]:SetCheck(true)
				elseif Apollo.GetConsoleVariable("fxaa.preset") == 2 then -- Note: There's no Ultra Low/Ultra High setting for 2
					self.wndVideo:SetRadioSel(parent.radio, 4)
					arBtns[4]:SetCheck(true)
				elseif Apollo.GetConsoleVariable("fxaa.preset") == 1 then
					self.wndVideo:SetRadioSel(parent.radio, 5)
					arBtns[5]:SetCheck(true)
				else
					self.wndVideo:SetRadioSel(parent.radio, 6)
					arBtns[6]:SetCheck(true)
				end
			elseif parent.consoleVar == "world.propScreenHeightPercentMin" then
				if Apollo.GetConsoleVariable("world.propScreenHeightPercentMin") == 5 then
					self.wndVideo:SetRadioSel(parent.radio, 1)
					arBtns[1]:SetCheck(true)
				elseif Apollo.GetConsoleVariable("world.propScreenHeightPercentMin") == 8 then
					self.wndVideo:SetRadioSel(parent.radio, 2)
					arBtns[2]:SetCheck(true)
				else
					self.wndVideo:SetRadioSel(parent.radio, 3)
					arBtns[3]:SetCheck(true)
				end
			elseif parent.consoleVar == "particle.envParticleScale" then
				if Apollo.GetConsoleVariable("particle.envParticleScale") == 1 then
					self.wndVideo:SetRadioSel(parent.radio, 1)
					arBtns[1]:SetCheck(true)
				elseif Apollo.GetConsoleVariable("particle.envParticleScale") == 0.5 then
					self.wndVideo:SetRadioSel(parent.radio, 2)
					arBtns[2]:SetCheck(true)
				elseif Apollo.GetConsoleVariable("particle.envParticleScale") == 0.25 then
					self.wndVideo:SetRadioSel(parent.radio, 3)
					arBtns[3]:SetCheck(true)
				else
					self.wndVideo:SetRadioSel(parent.radio, 4)
					arBtns[4]:SetCheck(true)
				end
			elseif parent.consoleVar == "spell.visualSuppression" then
				if Apollo.GetConsoleVariable("spell.visualSuppression") == 0 then
					self.wndVideo:SetRadioSel(parent.radio, 1)
					arBtns[1]:SetCheck(true)
				elseif Apollo.GetConsoleVariable("spell.visualSuppression") == 0.5 then
					self.wndVideo:SetRadioSel(parent.radio, 2)
					arBtns[2]:SetCheck(true)
				elseif Apollo.GetConsoleVariable("spell.visualSuppression") < 1.0 then
					self.wndVideo:SetRadioSel(parent.radio, 3)
					arBtns[3]:SetCheck(true)
				else
					self.wndVideo:SetRadioSel(parent.radio, 4)
					arBtns[4]:SetCheck(true)
				end
			elseif parent.consoleVar == "lod.landlod" then
				if Apollo.GetConsoleVariable("lod.landlod") == 1 then
					self.wndVideo:SetRadioSel(parent.radio, 1)
					arBtns[1]:SetCheck(true)
				else
					self.wndVideo:SetRadioSel(parent.radio, 2)
					arBtns[2]:SetCheck(true)
				end
			elseif parent.consoleVar == "draw.shadows" then
				if Apollo.GetConsoleVariable("draw.shadows") == true then
					if Apollo.GetConsoleVariable("lod.shadowMapSize") == 4096 then
						self.wndVideo:SetRadioSel(parent.radio, 1)
						arBtns[1]:SetCheck(true)
					elseif Apollo.GetConsoleVariable("lod.shadowMapSize") == 2048 then
						self.wndVideo:SetRadioSel(parent.radio, 2)
						arBtns[2]:SetCheck(true)
					else
						self.wndVideo:SetRadioSel(parent.radio, 3)
						arBtns[3]:SetCheck(true)
					end
				else
					self.wndVideo:SetRadioSel(parent.radio, 4)
					arBtns[4]:SetCheck(true)
				end
			else
				self.wndVideo:SetRadioSel(parent.radio, Apollo.GetConsoleVariable(parent.consoleVar) + 1)
				if arBtns[Apollo.GetConsoleVariable(parent.consoleVar) + 1] ~= nil then
					arBtns[Apollo.GetConsoleVariable(parent.consoleVar) + 1]:SetCheck(true)
				end
			end

			local strLabel = Apollo.GetString("Options_Unspecified")
			for idxBtn = 1, #arBtns do
				if arBtns[idxBtn]:IsChecked() then
					strLabel = arBtns[idxBtn]:GetText()
				end
			end

			parent.wnd:SetText(strLabel)
		end
	end

	self:FillConfigureList()

	local bIsInGame = IsInGame()
	self.OptionsDlg:FindChild("AddonsBtn"):Enable(bIsInGame)
	self.OptionsDlg:FindChild("AddonsBtn"):FindChild("RightArrowArt"):Show(bIsInGame)
	self.OptionsDlg:FindChild("Camp"):Enable(bIsInGame)
	if not bIsInGame then
		self.OptionsDlg:FindChild("AddonsBtn"):SetCheck(false)
		self.wndAddons:Show(false)
	end
	
	self:HelperCheckForErrorIndicator()
end

function OptionsAddon:HelperCheckForErrorIndicator()
	local wndErrorIndicator = self.OptionsDlg:FindChild("ErrorIndicator")
	local wndGrid = self.wndAddons:FindChild("AddonGrid")
	if wndErrorIndicator and wndGrid then
		wndErrorIndicator:Show(false)
		self:GetAddonsList()
		for idx, tAddon in pairs(self.tAddons) do
			if tAddon.eStatus == OptionsScreen.CodeEnumAddonStatus.ParsingError or tAddon.eStatus == OptionsScreen.CodeEnumAddonStatus.RunningWithError or tAddon.eStatus == OptionsScreen.CodeEnumAddonStatus.Suspended then
				wndErrorIndicator:Show(true)
			end
		end
		
		if wndErrorIndicator:IsShown() then
			wndGrid:SetSortColumn(EnumAddonColumns.Status, true)--sort descending
		end
	end
end

function OptionsAddon:OnInvokeOptionsScreen(nOption)
	self.wndAddCoins:Show(false)
	self.wndDemoGoodbye:Show(false, true)
	self.wndDemo:Show(false, true)
	if nOption == 1 then
		self.wndDemoGoodbye:Show(true)
		return
	elseif nOption == 2 then
		CloseOptions()
		Camp()
		return
	end

	self:InitOptionsControls()
	if IsDemo() then
		self.wndDemo:Show(true)
	end
end

function OptionsAddon:OnReturnToDemo(iOption)
	self.wndDemo:Show(false)
	self.wndDemoGoodbye:Show(false)
	CloseOptions()
end

function OptionsAddon:OnInvokeRestart(wndHandler, wndControl, eMouseButton)
	CloseOptions()
	Camp()
end

function OptionsAddon:OnToggleCoinBtn()
	self.wndAddCoins:Show(true)
	self.wndAddCoins:FindChild("InsertCoinPassword"):SetText("")
	self.wndAddCoins:FindChild("InsertCoinPassword"):SetFocus()
	self.wndAddCoins:FindChild("InsertCoin"):Enable(false)
	self.wndAddCoins:ToFront()
	--self.wndDemo:Show(false)
end

function OptionsAddon:OnHideAddCoin()
	self.wndAddCoins:Show(false)
end

function OptionsAddon:OnPasswordChanged(wndHandler, wndControl, strNew)
	self.wndAddCoins:FindChild("InsertCoin"):Enable(strNew == "g4ffer")
end

function OptionsAddon:OnInsertCoin()
	if self.wndAddCoins:FindChild("InsertCoinPassword"):GetText() == "g4ffer" then
		AddDemoTime(300)
	end
end

------------------------------------------------------------------------------------------
-- End Demo
------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------

function OptionsAddon:OnReloadUI()
	self:HelperUncheckAllInnerFrame()
	ReloadUI()

	self:HelperCheckForErrorIndicator()
end

------------------------------------------------------------------------------------------

function OptionsAddon:FillDisplayList()
	local exclusiveDisplayMode = Apollo.GetConsoleVariable("video.exclusiveDisplayMode")
	local arModes = EnumerateDisplayModes()
	local nSel = 0
	local nPos = self.wndVideo:FindChild("ResolutionParent"):FindChild("Resolution"):GetVScrollPos()
	self.wndVideo:FindChild("ResolutionParent"):FindChild("Resolution"):DeleteAll()
	for i, tMode in ipairs(arModes) do
		if tMode.vec.x == exclusiveDisplayMode.x and tMode.vec.y == exclusiveDisplayMode.y and tMode.vec.z == exclusiveDisplayMode.z then
			nSel = i
		end
		local str = tMode.strDisplay
		self.wndVideo:FindChild("ResolutionParent"):FindChild("Resolution"):AddRow(str, "", tMode)
	end
	self.bValidResolution = (nSel > 0)
	self.wndVideo:FindChild("ResolutionParent"):FindChild("Resolution"):SetCurrentRow(nSel)
	self.wndVideo:FindChild("ResolutionParent"):FindChild("Resolution"):SetVScrollPos(nPos)

	if not Apollo.GetConsoleVariable("video.exclusive") then
		self.wndVideo:FindChild("DropToggleExclusive"):Enable(false)
		self.wndVideo:FindChild("DropToggleExclusive"):SetText("")
	else
		self.wndVideo:FindChild("DropToggleExclusive"):Enable(true)
		local tDisplayMode = Apollo.GetConsoleVariable("video.exclusiveDisplayMode")
		self.wndVideo:FindChild("DropToggleExclusive"):SetText(tDisplayMode.x .."x".. tDisplayMode.y .."@".. tDisplayMode.z)
	end
end

function OptionsAddon:OnMappedOptionsCheckbox(wndHandler, wndControl)
	local tMapping = wndControl:GetData()
	Apollo.SetConsoleVariable(tMapping.consoleVar, wndControl:IsChecked())
	self:EnableVideoControls()
	self:OnMappedOptionsCheckboxHider()
	
	if tMapping.requiresRestart then
		self:ShowChangeRestartBlocker()
	end
end

function OptionsAddon:OnMappedOptionsCheckboxHider(wndHandler, wndControl)
	self.wndTargeting:FindChild("EnemyNPCBeneficialDisplayBtn"):Enable(self.wndTargeting:FindChild("EnemyDisplayBtn"):IsChecked())
	self.wndTargeting:FindChild("EnemyNPCDetrimentalDisplayBtn"):Enable(self.wndTargeting:FindChild("EnemyDisplayBtn"):IsChecked())
	self.wndTargeting:FindChild("EnemyPlayerBeneficialDisplayBtn"):Enable(self.wndTargeting:FindChild("EnemyDisplayBtn"):IsChecked())
	self.wndTargeting:FindChild("EnemyPlayerDetrimentalDisplayBtn"):Enable(self.wndTargeting:FindChild("EnemyDisplayBtn"):IsChecked())

	self.wndTargeting:FindChild("PartyAllyDisplayBtn"):Enable(self.wndTargeting:FindChild("AllyDisplayBtn"):IsChecked())
	self.wndTargeting:FindChild("AllyNPCBeneficialDisplayBtn"):Enable(self.wndTargeting:FindChild("AllyDisplayBtn"):IsChecked())
	self.wndTargeting:FindChild("AllyNPCDetrimentalDisplayBtn"):Enable(self.wndTargeting:FindChild("AllyDisplayBtn"):IsChecked())
	self.wndTargeting:FindChild("AllyPlayerBeneficialDisplayBtn"):Enable(self.wndTargeting:FindChild("AllyDisplayBtn"):IsChecked())
	self.wndTargeting:FindChild("AllyPlayerDetrimentalDisplayBtn"):Enable(self.wndTargeting:FindChild("AllyDisplayBtn"):IsChecked())
end

function OptionsAddon:OnOptionsSliderChanged(wndHandler, wndControl, fValue, fOldValue)
	local tMapping = wndControl:GetData()
	if type(tMapping.consoleVar) == "table" then
		for idx, strConsoleVar in pairs(tMapping.consoleVar) do
			Apollo.SetConsoleVariable(strConsoleVar, fValue)
		end
	else
		Apollo.SetConsoleVariable(tMapping.consoleVar, fValue)
	end

	if tMapping.buddy ~= nil then
		local strFormat = "%s"
		if tMapping.format ~= nil then
			strFormat = tMapping.format
		end

		if type(tMapping.consoleVar) == "table" then
			tMapping.buddy:SetText(string.format(strFormat, Apollo.GetConsoleVariable(tMapping.consoleVar[1])))
		else
			tMapping.buddy:SetText(string.format(strFormat, Apollo.GetConsoleVariable(tMapping.consoleVar)))
		end
	end

	self:RefreshPresetVideoSelection()
	
	if tMapping.requiresRestart then
		self:ShowChangeRestartBlocker()
	end
end

function OptionsAddon:OnTextureFilteringRadio(wndHandler, wndControl)
	local ndx = wndControl:GetParent():GetRadioSel("TextureFiltering")
	if ndx == 1 then
		Apollo.SetConsoleVariable("lod.textureFilter", 0)
	elseif ndx == 2 then
		Apollo.SetConsoleVariable("lod.textureFilter", 1)
	elseif ndx == 3 then
		Apollo.SetConsoleVariable("lod.textureFilter", 2)
	end
	wndControl:GetParent():GetParent():SetText(wndControl:GetText())
	wndControl:GetParent():Close()
	
	self:ShowChangeRestartBlocker()
end

function OptionsAddon:OnClutterDensityRadio(wndHandler, wndControl)
	Apollo.SetConsoleVariable("lod.clutterDensity", wndControl:GetParent():GetRadioSel("ClutterDensity") - 1)
	wndControl:GetParent():GetParent():SetText(wndControl:GetText())
	wndControl:GetParent():Close()
end

function OptionsAddon:OnTextureResolutionRadio(wndHandler, wndControl)
	Apollo.SetConsoleVariable("lod.textureLodBias", wndControl:GetParent():GetRadioSel("TextureResolution") - 1)
	Apollo.SetConsoleVariable("lod.textureLodMin", wndControl:GetParent():GetRadioSel("TextureResolution") - 1)
	wndControl:GetParent():GetParent():SetText(wndControl:GetText())
	wndControl:GetParent():Close()
end

function OptionsAddon:OnFXAARadio(wndHandler, wndControl)
	local ndx = wndControl:GetParent():GetRadioSel("FXAA")
	if ndx == 1 then
		Apollo.SetConsoleVariable("fxaa.preset", 5)
	elseif ndx == 2 then
		Apollo.SetConsoleVariable("fxaa.preset", 4)
	elseif ndx == 3 then
		Apollo.SetConsoleVariable("fxaa.preset", 3)
	elseif ndx == 4 then
		Apollo.SetConsoleVariable("fxaa.preset", 2)
	elseif ndx == 5 then
		Apollo.SetConsoleVariable("fxaa.preset", 1)
	elseif ndx == 6 then
		Apollo.SetConsoleVariable("fxaa.preset", 0)
	end
	Apollo.SetConsoleVariable("fxaa.enable", ndx ~= 6)

	wndControl:GetParent():GetParent():SetText(wndControl:GetText())
	wndControl:GetParent():Close()
end

function OptionsAddon:OnSceneDetailRadio(wndHandler, wndControl)
	local ndx = wndControl:GetParent():GetRadioSel("SceneDetail")
	if ndx == 1 then
		Apollo.SetConsoleVariable("world.propScreenHeightPercentMin", 5)
	elseif ndx == 2 then
		Apollo.SetConsoleVariable("world.propScreenHeightPercentMin", 8)
	elseif ndx == 3 then
		Apollo.SetConsoleVariable("world.propScreenHeightPercentMin", 12)
	end

	wndControl:GetParent():GetParent():SetText(wndControl:GetText())
	wndControl:GetParent():Close()
end

function OptionsAddon:OnParticleScaleRadio(wndHandler, wndControl)
	local ndx = wndControl:GetParent():GetRadioSel("ParticleScale")
	if ndx == 1 then
		Apollo.SetConsoleVariable("particle.envParticleScale", 1)
	elseif ndx == 2 then
		Apollo.SetConsoleVariable("particle.envParticleScale", 0.5)
	elseif ndx == 3 then
		Apollo.SetConsoleVariable("particle.envParticleScale", 0.25)
	elseif ndx == 4 then
		Apollo.SetConsoleVariable("particle.envParticleScale", 0.1)
	end

	wndControl:GetParent():GetParent():SetText(wndControl:GetText())
	wndControl:GetParent():Close()
end

function OptionsAddon:OnVisualSupressionRadio(wndHandler, wndControl)
	local ndx = wndControl:GetParent():GetRadioSel("VisualSupression")
	if ndx == 1 then
		Apollo.SetConsoleVariable("spell.visualSuppression", 0)
	elseif ndx == 2 then
		Apollo.SetConsoleVariable("spell.visualSuppression", 0.5)
	elseif ndx == 3 then
		Apollo.SetConsoleVariable("spell.visualSuppression", 0.9)
	elseif ndx == 4 then
		Apollo.SetConsoleVariable("spell.visualSuppression", 1.0) -- GOTCHA: These are reversed. Higher is better performance.
	end

	wndControl:GetParent():GetParent():SetText(wndControl:GetText())
	wndControl:GetParent():Close()
end

function OptionsAddon:OnRenderTargetRadio(wndHandler, wndControl)
	local ndx = wndControl:GetParent():GetRadioSel("RenderTargetScale")
	if ndx == 1 then
		Apollo.SetConsoleVariable("lod.renderTargetScale", 1)
	elseif ndx == 2 then
		Apollo.SetConsoleVariable("lod.renderTargetScale", 0.75)
	elseif ndx == 3 then
		Apollo.SetConsoleVariable("lod.renderTargetScale", 0.5)
	end

	wndControl:GetParent():GetParent():SetText(wndControl:GetText())
	wndControl:GetParent():Close()
end

function OptionsAddon:OnLandLODRadio(wndHandler, wndControl)
	local ndx = wndControl:GetParent():GetRadioSel("LandLOD")
	if ndx == 1 then
		Apollo.SetConsoleVariable("lod.landlod", 1)
	elseif ndx == 2 then
		Apollo.SetConsoleVariable("lod.landlod", 0)
	end

	wndControl:GetParent():GetParent():SetText(wndControl:GetText())
	wndControl:GetParent():Close()
end

function OptionsAddon:OnShadowsRadio(wndHandler, wndControl)
	local ndx = wndControl:GetParent():GetRadioSel("ShadowSetting")
	if ndx == 1 then
		Apollo.SetConsoleVariable("draw.shadows", true)
		Apollo.SetConsoleVariable("lod.shadowMapSize", 4096)
	elseif ndx == 2 then
		Apollo.SetConsoleVariable("draw.shadows", true)
		Apollo.SetConsoleVariable("lod.shadowMapSize", 2048)
	elseif ndx == 3 then
		Apollo.SetConsoleVariable("draw.shadows", true)
		Apollo.SetConsoleVariable("lod.shadowMapSize", 1024)
	else -- off
		Apollo.SetConsoleVariable("draw.shadows", false)
	end

	wndControl:GetParent():GetParent():SetText(wndControl:GetText())
	wndControl:GetParent():Close()
end

function OptionsAddon:OnResolutionSelChanged(wndHandler, wndControl, nRow)
	local tMode = wndControl:GetCellData(nRow, 1)
	if tMode == nil then
		return
	end
	self.wndVideo:FindChild("ResolutionParent"):Show(false)
	self.wndVideo:FindChild("DropToggleExclusive"):SetText(tMode.strDisplay)
	self.tPrevExcRes = Apollo.GetConsoleVariable("video.exclusiveDisplayMode")
	Apollo.SetConsoleVariable("video.exclusiveDisplayMode", tMode.vec)

	if Apollo.GetConsoleVariable("video.fullscreen") == true and Apollo.GetConsoleVariable("video.exclusive") == true then
		Apollo.StartTimer("ResExChangedTimer")
		self.wndVideoConfirm:Show(true)
		self.wndVideoConfirm:SetData(2)
		self.wndVideoConfirm:FindChild("TextTimer"):SetText("15")
		self.nOptionsTimer = 0
	end
end

function OptionsAddon:OnResExChangedTimer()
	if self.nOptionsTimer < 15 then
		self.nOptionsTimer = self.nOptionsTimer + 1
		self.wndVideoConfirm:Show(true)
		self.wndVideoConfirm:FindChild("TextTimer"):SetText(15 - self.nOptionsTimer)
		Apollo.StartTimer("ResExChangedTimer", 1.000, false)
	else
		self.nOptionsTimer = 0
		self.wndVideoConfirm:Show(false)

		if self.tPrevExcRes ~= nil then
			self.wndVideo:FindChild("DropToggleExclusive"):SetText(self.tPrevExcRes.x .."x".. self.tPrevExcRes.y .."@".. self.tPrevExcRes.z)
			Apollo.SetConsoleVariable("video.exclusiveDisplayMode", self.tPrevExcRes)
			self.tPrevExcRes = nil
		end
	end
end

function OptionsAddon:OnWindowModeToggle(wndHandler, wndControl)
	if wndHandler ~= wndControl then -- in case the window closing trips this
		return
	end
	wndControl:FindChild("ChoiceContainer"):Show(wndControl:IsChecked())
	self:RefreshPresetVideoSelection()
end

function OptionsAddon:OnWindowModeToggleRes(wndHandler, wndControl)
	self.wndVideo:FindChild("ResolutionParent"):Show(wndControl:IsChecked())
	self:FillDisplayList()
end

--Resolution Settings (custom handlers)
function OptionsAddon:OnResWindowed(wndHandler, wndControl)
	self.tPrevResSettings = {Apollo.GetConsoleVariable("video.fullscreen"), Apollo.GetConsoleVariable("video.exclusive")}
	Apollo.SetConsoleVariable("video.fullscreen", false)
	Apollo.SetConsoleVariable("video.exclusive", false)
	self:EnableVideoControls()
	wndControl:GetParent():GetParent():SetText(wndControl:GetText())
	wndControl:GetParent():Close()
end

function OptionsAddon:OnResFullscreen(wndHandler, wndControl)
	self.tPrevResSettings = {Apollo.GetConsoleVariable("video.fullscreen"), Apollo.GetConsoleVariable("video.exclusive")}
	Apollo.SetConsoleVariable("video.fullscreen", true)
	Apollo.SetConsoleVariable("video.exclusive", false)
	self:EnableVideoControls()
	wndControl:GetParent():GetParent():SetText(wndControl:GetText())
	wndControl:GetParent():Close()
end

function OptionsAddon:OnResFullscreenEx(wndHandler, wndControl)
	self.tPrevResSettings = {Apollo.GetConsoleVariable("video.fullscreen"), Apollo.GetConsoleVariable("video.exclusive")}
	Apollo.SetConsoleVariable("video.fullscreen", true)
	Apollo.SetConsoleVariable("video.exclusive", true)
	self:EnableVideoControls()
	wndControl:GetParent():GetParent():SetText(wndControl:GetText())
	wndControl:GetParent():Close()

	self.wndVideoConfirm:Show(true)
	self.wndVideoConfirm:SetData(1)
	self.wndVideoConfirm:FindChild("TextTimer"):SetText("15")
	Apollo.StartTimer("ResChangedTimer")
	self.nOptionsTimer = 0
end

function OptionsAddon:OnResChangedTimer()
	if self.nOptionsTimer < 15 then
		self.nOptionsTimer = self.nOptionsTimer + 1
		self.wndVideoConfirm:Show(true)
		self.wndVideoConfirm:FindChild("TextTimer"):SetText(15 - self.nOptionsTimer)
		Apollo.StartTimer("ResChangedTimer")
	else
		self.nOptionsTimer = 0
		self.wndVideoConfirm:Show(false)

		if self.tPrevResSettings ~= nil then
			Apollo.SetConsoleVariable("video.fullscreen", self.tPrevResSettings[1])
			Apollo.SetConsoleVariable("video.exclusive", self.tPrevResSettings[2])
			self.tPrevResSettings = nil
			self:InitOptionsControls()
			self:EnableVideoControls()
		end
	end
end

function OptionsAddon:EnableVideoControls()
	self:RefreshPresetVideoSelection()
	self:FillDisplayList()
end

function OptionsAddon:RefreshPresetVideoSelection()
	local strMatchingPreset = "Custom"
	if not self.bCustomVideoSettings then
		for strPreset, tPreset in pairs(ktVideoSettingLevels) do
			local bAllMatching = true
			for strConsoleVar, default in pairs(tPreset) do
				if Apollo.GetConsoleVariable(strConsoleVar) ~= default then
					bAllMatching = false
					break
				end
			end

			if bAllMatching then
				strMatchingPreset = strPreset
			end
			self.wndVideo:FindChild("DropTogglePresetSettings"):FindChild(strPreset):SetCheck(false)
		end
	end

	self.wndVideo:FindChild("DropTogglePresetSettings"):FindChild(strMatchingPreset):SetCheck(true)
	self.wndVideo:FindChild("DropTogglePresetSettings"):SetText(self.wndVideo:FindChild("DropTogglePresetSettings"):FindChild(strMatchingPreset):GetText())
end

function OptionsAddon:OnChangeConfirmBtn(wndHandler, wndControl)
	Apollo.StopTimer("ResExChangedTimer")
	Apollo.StopTimer("ResChangedTimer")
	self.wndVideoConfirm:Show(false)
	self.tPrevExcRes = nil
	self.tPrevResSettings = nil
end

function OptionsAddon:OnChangeCancelBtn(wndHandler, wndControl)
	Apollo.StopTimer("ResExChangedTimer")
	Apollo.StopTimer("ResChangedTimer")
	self.nOptionsTimer = 0
	self.wndVideoConfirm:Show(false)

	if self.wndVideoConfirm:GetData() == 1 then --res
		if self.tPrevResSettings ~= nil then
			Apollo.SetConsoleVariable("video.fullscreen", self.tPrevResSettings[1])
			Apollo.SetConsoleVariable("video.exclusive", self.tPrevResSettings[2])
			self.tPrevResSettings = nil
			self:InitOptionsControls()
			self:EnableVideoControls()
		end
	else -- res exc
		if self.tPrevExcRes ~= nil then
			self.wndVideo:FindChild("DropToggleExclusive"):SetText(self.tPrevExcRes.x .."x".. self.tPrevExcRes.y .."@".. self.tPrevExcRes.z)
			Apollo.SetConsoleVariable("video.exclusiveDisplayMode", self.tPrevExcRes)
			self.tPrevExcRes = nil
		end
	end
end

function OptionsAddon:ShowChangeRestartBlocker()
	self.wndRequiresRestartConfirm:Show(IsInGame())
end

function OptionsAddon:OnChangeRestartConfirmBtn(wndHandler, wndControl, eMouseButton)
	self.wndRequiresRestartConfirm:Show(false)
	RequestCamp()
end

function OptionsAddon:OnChangeRestartCancelBtn(wndHandler, wndControl, eMouseButton)
	self.wndRequiresRestartConfirm:Show(false)
end

-- Free form Targetting
function OptionsAddon:OnAlwaysFaceCheck(wndHandler, wndControl, eMouseButton)
	Apollo.SetConsoleVariable("Player.ignoreAlwaysFaceTarget", false)
	self.wndTargeting:FindChild("FacingLockBtn"):Enable(true)
	self.wndTargeting:FindChild("FacingLockBtn"):SetBGColor("white")
end

function OptionsAddon:OnAlwaysFaceUncheck(wndHandler, wndControl, eMouseButton)
	Apollo.SetConsoleVariable("Player.ignoreAlwaysFaceTarget", true)
	self.wndTargeting:FindChild("FacingLockBtn"):Enable(false)
	self.wndTargeting:FindChild("FacingLockBtn"):SetBGColor("UI_AlphaPercent50")
end

function OptionsAddon:OnFacingLockCheck(wndHandler, wndControl, eMouseButton)
	Apollo.SetConsoleVariable("Player.disableFacingLock", false)
end

function OptionsAddon:OnFacingLockUncheck(wndHandler, wndControl, eMouseButton)
	Apollo.SetConsoleVariable("Player.disableFacingLock", true)
end

-- Movement
function OptionsAddon:OnDashDoubleTapBtn(wndHandler, wndControl, eMouseButton)
	Apollo.SetConsoleVariable("player.doubleTapToDash", wndControl:IsChecked())
	Apollo.SetConsoleVariable("player.showDoubleTapToDash", wndControl:IsChecked())
end

-- Abilities
function OptionsAddon:OnAbilityQueueBtn(wndHandler, wndControl, eMouseButton)
	if wndControl:IsChecked() then
		Apollo.SetConsoleVariable("player.abilityQueueMax", 500)
	else
		Apollo.SetConsoleVariable("player.abilityQueueMax", 0)
	end

	self:OnOptionsCheck()
end

function OptionsAddon:OnAbilityQueueLengthChanged(wndHandler, wndControl, fValue, fOldValue)
	Apollo.SetConsoleVariable("player.abilityQueueMax", fValue)
	self.wndTargeting:FindChild("AbilityQueueLengthEditBox"):SetText(string.format("%.0f", fValue))
end

function OptionsAddon:OnMouseTurnSpeedChanged(wndHandler, wndControl, fValue, fOldValue)
	local strRound = string.format("%.2f", fValue)
	Apollo.SetConsoleVariable("player.turningSpeedMouse", tonumber(strRound))
	self.wndTargeting:FindChild("MouseTurnSpeedEditBox"):SetText(strRound)
end

function OptionsAddon:OnKeyboardTurnSpeedChanged(wndHandler, wndControl, fValue, fOldValue)
	local strRound = string.format("%.2f", fValue)
	Apollo.SetConsoleVariable("player.turningSpeedKeyboard", tonumber(strRound))
	self.wndTargeting:FindChild("KeyboardTurnSpeedEditBox"):SetText(strRound)
end

function OptionsAddon:OnEnteredCombat()
	self:OnOptionsClose()
end

function OptionsAddon:OnRestoreDefaults()
	for iTable, tTable in pairs({ self.mapCB2CVs, self.mapSB2CVs, self.mapDDParents }) do
		for idx, tVar in pairs(tTable) do
			if tVar.wnd and tVar.wnd:IsVisible() then
				local oldValue = Apollo.GetConsoleVariable(tVar.consoleVar)
				Apollo.ResetConsoleVariable(tVar.consoleVar)
				if tVar.requiresRestart and oldValue ~= Apollo.GetConsoleVariable(tVar.consoleVar) then
					self:ShowChangeRestartBlocker()
				end
			end
		end
	end
	self:OnOptionsCheck()

	self.wndVideo:FindChild("RefreshAnimation"):SetSprite("CRB_WindowAnimationSprites:sprWinAnim_BirthSmallTemp")
end

function OptionsAddon:OnCheckCombatMusicFlair( wndHandler, wndControl, eMouseButton )
	Apollo.SetConsoleVariable("sound.intenseBattleMusic", true)
end

function OptionsAddon:OnUncheckCombatMusicFlair( wndHandler, wndControl, eMouseButton )
	Apollo.SetConsoleVariable("sound.intenseBattleMusic", false)
end

function OptionsAddon:OnCheckPlaySoundInBackground( wndHandler, wndControl, eMouseButton )
	Apollo.SetConsoleVariable("sound.playInBackground", true)
end

function OptionsAddon:OnUncheckPlaySoundInBackground( wndHandler, wndControl, eMouseButton )
	Apollo.SetConsoleVariable("sound.playInBackground", false)
end

function OptionsAddon:OnMuteCheck( wndHandler, wndControl)
	for idx, tAdjustment in pairs(self.mapSB2CVs) do
		if tAdjustment.wnd and tAdjustment.wnd:IsVisible() and tAdjustment.format then	
			local wndBlocker = tAdjustment.wnd:GetParent():FindChild("SliderBlocker")
			if wndBlocker then
				wndBlocker:Show(true)
			end

			tAdjustment.wnd:SetValue(0)
			tAdjustment.buddy:SetText(string.format(tAdjustment.format, 0))
			tAdjustment.wnd:Enable(false)
		end
	end

	self.wndSounds:FindChild("PlayInBackground"):Enable(false)
	Apollo.SetConsoleVariable("sound.mute", true)
end

function OptionsAddon:OnMuteUncheck( wndHandler, wndControl)
		for idx, tAdjustment in pairs(self.mapSB2CVs) do
			if tAdjustment.wnd and tAdjustment.wnd:IsVisible()  and tAdjustment.format and tAdjustment.consoleVar then	
				local wndBlocker = tAdjustment.wnd:GetParent():FindChild("SliderBlocker")
				if wndBlocker then
					wndBlocker:Show(false)
				end

				local nValue = Apollo.GetConsoleVariable(tAdjustment.consoleVar)
				tAdjustment.wnd:SetValue(nValue)
				tAdjustment.buddy:SetText(string.format(tAdjustment.format, nValue))
				tAdjustment.wnd:Enable(true)
			end
		end

	self.wndSounds:FindChild("PlayInBackground"):Enable(true)
	Apollo.SetConsoleVariable("sound.mute", false)
end

function OptionsAddon:OnCheckCinematicSubtitles( wndHandler, wndControl, eMouseButton )
	Apollo.SetConsoleVariable("draw.subtitles", true)
end

function OptionsAddon:OnUncheckCinematicSubtitles( wndHandler, wndControl, eMouseButton )
	Apollo.SetConsoleVariable("draw.subtitles", false)
end

function OptionsAddon:OnVideoPresetSetting(wndHandler, wndControl, eMouseButton)
	if wndControl:GetName() ~= "Custom" then
		for strConsoleVar, default in pairs(ktVideoSettingLevels[wndControl:GetName()]) do
			Apollo.SetConsoleVariable(strConsoleVar, default)
		end
	end

	self.bCustomVideoSettings = wndControl:GetName() == "Custom"

	self:EnableVideoControls()
	self:InitOptionsControls()
	local wndParent = wndControl:GetData()
	wndParent:SetText(wndControl:GetText())
	wndParent:FindChild("ChoiceContainer"):Close()
end

function OptionsAddon:OnStuck(wndHandler, wndControl, eMouseButton)
	ShowStuckUI()
	CloseOptions()
end

function OptionsAddon:OnTelegraphColorResetBtn(wndHandler, wndControl, eMouseButton)
	local wndTelegraphChoiceContainer = wndControl:GetParent()
	local tTelegraphColor = wndTelegraphChoiceContainer:GetData()
	local tSet = tTelegraphColor.tSets[Apollo.GetConsoleVariable("spell.telegraphColorSet")]

	Apollo.ResetConsoleVariable(tSet.consoleVarFillOpacity)
	Apollo.ResetConsoleVariable(tSet.consoleVarOutlineOpacity)

	if not tSet.bReadOnlyColors then
		Apollo.ResetConsoleVariable(tSet.consoleVarColorR)
		Apollo.ResetConsoleVariable(tSet.consoleVarColorG)
		Apollo.ResetConsoleVariable(tSet.consoleVarColorB)
	end

	self:UpdateTelegraphColorWindow(wndTelegraphChoiceContainer:GetParent():GetParent())
end

function OptionsAddon:OnColorChanged(wndHandler, wndControl, crNewColor)
	local wndTelegraphChoiceContainer = wndControl:GetParent()
	local tTelegraphColor = wndTelegraphChoiceContainer:GetData()
	local tSet = tTelegraphColor.tSets[Apollo.GetConsoleVariable("spell.telegraphColorSet")]

	local nRed = math.floor(crNewColor.r * 255.0)
	local nGreen = math.floor(crNewColor.g * 255.0)
	local nBlue = math.floor(crNewColor.b * 255.0)

	Apollo.SetConsoleVariable(tSet.consoleVarColorR, nRed)
	Apollo.SetConsoleVariable(tSet.consoleVarColorB, nBlue)
	Apollo.SetConsoleVariable(tSet.consoleVarColorG, nGreen)

	wndTelegraphChoiceContainer:FindChild("R_EditBox"):SetText(nRed)
	wndTelegraphChoiceContainer:FindChild("G_EditBox"):SetText(nGreen)
	wndTelegraphChoiceContainer:FindChild("B_EditBox"):SetText(nBlue)

	local wndColorBtn = wndTelegraphChoiceContainer:GetParent()
	wndColorBtn:FindChild("Color:Inner"):SetBGColor({crNewColor.r, crNewColor.g, crNewColor.b, 1.0})
	wndColorBtn:FindChild("Color:Outline"):SetBGColor({crNewColor.r, crNewColor.g, crNewColor.b, 1.0})

	RefreshCustomTelegraphColors() -- thume says this is a super cheap call
end

function OptionsAddon:OnFillOpacityChanged(wndHandler, wndControl, fNewValue, fOldValue)
	local wndTelegraphChoiceContainer = wndControl:GetParent():GetParent()
	local tTelegraphColor = wndTelegraphChoiceContainer:GetData()
	local tSet = tTelegraphColor.tSets[Apollo.GetConsoleVariable("spell.telegraphColorSet")]

	Apollo.SetConsoleVariable(tSet.consoleVarFillOpacity, math.floor(fNewValue))

	self:RefreshAllTelegraphColorOpacityControls()
end

function OptionsAddon:OnTelegraphFillOpacityTextChanged(wndHandler, wndControl, strText)
	local wndTelegraphChoiceContainer = wndControl:GetParent():GetParent()
	local tTelegraphColor = wndTelegraphChoiceContainer:GetData()
	local tSet = tTelegraphColor.tSets[Apollo.GetConsoleVariable("spell.telegraphColorSet")]

	local strValue = strText:gsub('%D','')
	if strValue == '' then
		strValue = '0'
	end
	local nValue = math.min(100, math.max(tonumber(strValue), 0))

	Apollo.SetConsoleVariable(tSet.consoleVarFillOpacity, nValue)

	self:RefreshAllTelegraphColorOpacityControls()
end

function OptionsAddon:OnOutlineOpacityChanged(wndHandler, wndControl, fNewValue, fOldValue)
	local wndTelegraphChoiceContainer = wndControl:GetParent():GetParent()
	local tTelegraphColor = wndTelegraphChoiceContainer:GetData()
	local tSet = tTelegraphColor.tSets[Apollo.GetConsoleVariable("spell.telegraphColorSet")]

	Apollo.SetConsoleVariable(tSet.consoleVarOutlineOpacity, math.floor(fNewValue))

	self:RefreshAllTelegraphColorOpacityControls()
end

function OptionsAddon:OnTelegraphOutlineOpacityTextChanged(wndHandler, wndControl, strText)
	local wndTelegraphChoiceContainer = wndControl:GetParent():GetParent()
	local tTelegraphColor = wndTelegraphChoiceContainer:GetData()
	local tSet = tTelegraphColor.tSets[Apollo.GetConsoleVariable("spell.telegraphColorSet")]

	local strValue = strText:gsub('%D','')
	if strValue == '' then
		strValue = '0'
	end
	local nValue = math.min(100, math.max(tonumber(strValue), 0))

	Apollo.SetConsoleVariable(tSet.consoleVarOutlineOpacity, nValue)

	self:RefreshAllTelegraphColorOpacityControls()
end

function OptionsAddon:OnTelegraphColorTextChanged(wndHandler, wndControl, strText)
	local wndTelegraphChoiceContainer = wndControl:GetParent()
	local tTelegraphColor = wndTelegraphChoiceContainer:GetData()
	local tSet = tTelegraphColor.tSets[Apollo.GetConsoleVariable("spell.telegraphColorSet")]

	local strValue = strText:gsub('%D','')
	if strValue == '' then
		strValue = '0'
	end
	local nValue = math.min(255, math.max(tonumber(strValue), 0))

	Apollo.SetConsoleVariable(tSet[wndControl:GetData()], nValue)

	local crNewColor = ApolloColor.new(Apollo.GetConsoleVariable(tSet.consoleVarColorR), Apollo.GetConsoleVariable(tSet.consoleVarColorG), Apollo.GetConsoleVariable(tSet.consoleVarColorB))
	wndTelegraphChoiceContainer:FindChild("ColorPicker"):SetColor(crNewColor)
	local tSelection = wndControl:GetSel()
	wndControl:SetText(tostring(nValue))
	wndControl:SetSel(tSelection.cpCaret, tSelection.cpCaret)

	local wndColorBtn = wndTelegraphChoiceContainer:GetParent()
	wndColorBtn:FindChild("Color:Inner"):SetBGColor(crNewColor)
	wndColorBtn:FindChild("Color:Outline"):SetBGColor(crNewColor)

	RefreshCustomTelegraphColors()
end

function OptionsAddon:OnTelegraphWindowClosed(wndHandler, wndControl)
	RefreshCustomTelegraphColors()
end

function OptionsAddon:RefreshAllTelegraphColorOpacityControls()
	local nSet = Apollo.GetConsoleVariable("spell.telegraphColorSet")
	
	local wndTelelgraphColors = self.wndTargeting:FindChild("GroupContainer:TargettingDialogControls:TargettingOptionsControls:TelegraphOptionsFrame:TelelgraphColors")
	for idx, wndTelegraphColor in pairs(wndTelelgraphColors:GetChildren()) do
		local wndColorBtn = wndTelegraphColor:FindChild("ColorBtn")
		local wndTelegraphChoiceContainer = wndColorBtn:FindChild("TelegraphChoiceContainer")
		local tTelegraphColor = wndTelegraphChoiceContainer:GetData()
		local tSet = tTelegraphColor.tSets[nSet]
		
		local nFillOpacity = Apollo.GetConsoleVariable(tSet.consoleVarFillOpacity)
		local nOutlineOpacity = Apollo.GetConsoleVariable(tSet.consoleVarOutlineOpacity)
		
		wndColorBtn:FindChild("Color:Inner"):SetBGOpacity(nFillOpacity/100.0, 0.0)
		wndColorBtn:FindChild("Color:Outline"):SetBGOpacity(nOutlineOpacity/100.0, 0.0)
		
		wndTelegraphChoiceContainer:FindChild("InsideFillOpacity:InsideFillOpacityEditBox"):SetText(nFillOpacity)
		wndTelegraphChoiceContainer:FindChild("InsideFillOpacity:InsideFillOpacitySliderBar"):SetValue(nFillOpacity)
	
		wndTelegraphChoiceContainer:FindChild("OutlineOpacity:OutsideOpacityEditBox"):SetText(nOutlineOpacity)
		wndTelegraphChoiceContainer:FindChild("OutlineOpacity:OutsideOpacitySliderBar"):SetValue(nOutlineOpacity)
	end
	
	RefreshCustomTelegraphColors()
end

function OptionsAddon:EnableTelegraphColorControls()
	local nCurrentTelegraphColorChoice = Apollo.GetConsoleVariable("spell.telegraphColorSet")
	local wndTelegraphPresetSettings = self.wndTargeting:FindChild("GroupContainer:TargettingDialogControls:TargettingOptionsControls:TelegraphOptionsFrame:TelelgraphColorsHeader:DropToggleTelegraphPresetSettings")
	for idx, wndTelegraphPresetChoice in pairs(wndTelegraphPresetSettings:FindChild("ChoiceContainer"):GetChildren()) do
		local data = wndTelegraphPresetChoice:GetData()
		wndTelegraphPresetChoice:SetCheck(nCurrentTelegraphColorChoice == data)
		if nCurrentTelegraphColorChoice == data then
			wndTelegraphPresetSettings:SetText(wndTelegraphPresetChoice:GetText())
		end
	end

	local wndTelelgraphColors = self.wndTargeting:FindChild("GroupContainer:TargettingDialogControls:TargettingOptionsControls:TelegraphOptionsFrame:TelelgraphColors")
	for idx, wndTelegraphColor in pairs(wndTelelgraphColors:GetChildren()) do
		self:UpdateTelegraphColorWindow(wndTelegraphColor)
	end
end

function OptionsAddon:UpdateTelegraphColorWindow(wndTelegraphColor)
	local wndColorBtn = wndTelegraphColor:FindChild("ColorBtn")
	local wndTelegraphChoiceContainer = wndColorBtn:FindChild("TelegraphChoiceContainer")
	local tTelegraphColor = wndTelegraphChoiceContainer:GetData()
	local tSet = tTelegraphColor.tSets[Apollo.GetConsoleVariable("spell.telegraphColorSet")]

	local crColor
	local nR
	local nG
	local nB
	local nFillOpacity = Apollo.GetConsoleVariable(tSet.consoleVarFillOpacity)
	local nOutlineOpacity = Apollo.GetConsoleVariable(tSet.consoleVarOutlineOpacity)

	if tSet.bReadOnlyColors then
		crColor = tSet.crColor
		local tColor = crColor:ToTable()
		nR = math.floor(tColor.r*255.0)
		nG = math.floor(tColor.g*255.0)
		nB = math.floor(tColor.b*255.0)
		wndTelegraphChoiceContainer:FindChild("TelegraphColorBlocker"):Show(true)
	else
		nR = Apollo.GetConsoleVariable(tSet.consoleVarColorR)
		nG = Apollo.GetConsoleVariable(tSet.consoleVarColorG)
		nB = Apollo.GetConsoleVariable(tSet.consoleVarColorB)
		crColor = ApolloColor.new(nR/255, nG/255, nB/255)
		wndTelegraphChoiceContainer:FindChild("TelegraphColorBlocker"):Show(false)
	end

	local wndInner = wndColorBtn:FindChild("Color:Inner")
	wndInner:SetBGColor(crColor)
	wndInner:SetBGOpacity(nFillOpacity/100.0, 0.0)

	local wndOutline = wndColorBtn:FindChild("Color:Outline")
	wndOutline:SetBGColor(crColor)
	wndOutline:SetBGOpacity(nOutlineOpacity/100.0, 0.0)

	local wndR_EditBox = wndTelegraphChoiceContainer:FindChild("R_EditBox")
	wndR_EditBox:SetText(nR)
	wndR_EditBox:Enable(not tSet.bReadOnlyColors)
	local wndG_EditBox = wndTelegraphChoiceContainer:FindChild("G_EditBox")
	wndG_EditBox:SetText(nG)
	wndG_EditBox:Enable(not tSet.bReadOnlyColors)
	local wndB_EditBox = wndTelegraphChoiceContainer:FindChild("B_EditBox")
	wndB_EditBox:SetText(nB)
	wndB_EditBox:Enable(not tSet.bReadOnlyColors)

	wndTelegraphChoiceContainer:FindChild("InsideFillOpacity:InsideFillOpacityEditBox"):SetText(nFillOpacity)
	wndTelegraphChoiceContainer:FindChild("InsideFillOpacity:InsideFillOpacitySliderBar"):SetValue(nFillOpacity)

	wndTelegraphChoiceContainer:FindChild("OutlineOpacity:OutsideOpacityEditBox"):SetText(nOutlineOpacity)
	wndTelegraphChoiceContainer:FindChild("OutlineOpacity:OutsideOpacitySliderBar"):SetValue(nOutlineOpacity)

	local wndColorPicker = wndTelegraphChoiceContainer:FindChild("ColorPicker")
	wndColorPicker:SetColor(crColor)
	wndColorPicker:Enable(not tSet.bReadOnlyColors)
	
	RefreshCustomTelegraphColors()
end

function OptionsAddon:OnTelegraphColorBtnCheck(wndHandler, wndControl, eMouseButton)
	self:UpdateTelegraphColorWindow(wndControl:GetParent())

	local wndTelegraphChoiceContainer = wndControl:FindChild("TelegraphChoiceContainer")

	local tDisplay = Apollo.GetDisplaySize()
	if tDisplay and tDisplay.nWidth and tDisplay.nHeight then
		local tRect = {}
		tRect.l, tRect.t, tRect.r, tRect.b = wndTelegraphChoiceContainer:GetRect()
		local nWidth = tRect.r - tRect.l
		local nHeight = tRect.b - tRect.t
		local nDeltaX = 0
		local nDeltaY = 0

		local nCurrentX, nCurrentY = wndTelegraphChoiceContainer:GetPos()

		local wndParent = wndTelegraphChoiceContainer:GetParent()
		while wndParent ~= nil and wndParent:IsValid() do
			local nX, nY = wndParent:GetPos()
			nCurrentX = nCurrentX + nX
			nCurrentY = nCurrentY + nY
			wndParent = wndParent:GetParent()
		end

		nDeltaX = nCurrentX >= 0 and 0 or nCurrentX * -1
		nDeltaY = nCurrentY >= 0 and 0 or nCurrentY * -1
		strConstrainLabelOutput = strConstrainLabel
		nDeltaX = nCurrentX + nWidth > tDisplay.nWidth and tDisplay.nWidth - nCurrentX - nWidth or nDeltaX
		nDeltaY = nCurrentY + nHeight > tDisplay.nHeight and tDisplay.nHeight - nCurrentY - nHeight or nDeltaY

		local tLocation = wndTelegraphChoiceContainer:GetLocation():ToTable()
		tLocation.nOffsets = {
			tLocation.nOffsets[1] + nDeltaX,
			tLocation.nOffsets[2] + nDeltaY,
			tLocation.nOffsets[3] + nDeltaX,
			tLocation.nOffsets[4] + nDeltaY,
		}

		wndTelegraphChoiceContainer:MoveToLocation(WindowLocation.new(tLocation))
	end
end

function OptionsAddon:OnTelegraphColorModeOptionCheck(wndHandler, wndControl, eMouseButton)
	Apollo.SetConsoleVariable("spell.telegraphColorSet", wndControl:GetData())
	self:EnableTelegraphColorControls()
	wndControl:GetParent():Show(false)
	RefreshCustomTelegraphColors()
end

----------------------------------------------------------------------------------------
-- Options instance
---------------------------------------------------------------------------------------------------
local OptionsInst = OptionsAddon:new()
OptionsAddon:Init()

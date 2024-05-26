-- by Rylvns
-- Last edited on Saturday, May 25 (5/25/24); 8:18 PM (EST/EDT)

-- Version 1-ea
-- GitHub: https://github.com/Rylvns/public-projects/tree/main/modules/UIEmitter
-- Devforum: https://devforum.roblox.com/t/uiemitter-module-ui-particles-confetti/2913477

local Module = {
	DefaultConfigs = {
		Size = Vector2.new(10, 10),
		Position = Vector2.zero,
		Acceleration = Vector2.zero,
		Gravity = Vector2.zero,
		FrictionCoefficient = 1,
		LifeTime = 4,
		Properties = {},
		FadeIn = {
			Duration = 1,
			EasingStyle = Enum.EasingStyle.Linear,
			EasingDirection = Enum.EasingDirection.InOut,
			TweenProperties = {},
		},
		FadeOut = {
			Duration = 1,
			EasingStyle = Enum.EasingStyle.Linear,
			EasingDirection = Enum.EasingDirection.InOut,
			TweenProperties = {},
		},
		Texture = "",
	},
};

local RunService = game:GetService("RunService");
local Players = game:GetService("Players");
local Camera = workspace.CurrentCamera;

local function Lerp(Start, Goal, Alpha)
	return Start+(Goal-Start)*Alpha;
end;
local function LerpColor(Color1, Color2, Alpha)
	return Color3.new(Lerp(Color1.R, Color2.R, Alpha), Lerp(Color1.G, Color2.G, Alpha), Lerp(Color1.B, Color2.B, Alpha));
end;

local function Tween(Object, Time, Style, Direction, Properties)
	local TweenObject = game:GetService("TweenService"):Create(Object, TweenInfo.new(Time, Style, Direction, 0, false, 0), Properties);
	TweenObject:Play();
	return TweenObject;
end;

local function Token(Layout, Library)
	local Results = "";
	local Library = string.split(Library or "1234567890abcdefgh1234567890", "");
	for Int, String in ipairs(string.split(Layout == "" and table.concat(table.create(math.random(2, 64), "#")) or Layout, "")) do
		if String == "#" then
			String = Library[math.random(1, #Library)];
		end;
		Results = Results..String;
	end;
	return Results;
end;
local function NewGuid()
	return Token("########-####-####-####-############", "1234567890ABCDEFGH1234567890");
end;

local function TableLength(Table)
	local Results = 0;
	for Int, Value in pairs(Table) do
		Results += 1;
	end;
	return Results;
end;

local function CalculateRotatedPosition(PositionX, PositionY, CenterPositionX, CenterPositionY, RotationAngle)
	local AngleInRadians = math.rad(RotationAngle);
	local RelativeX = PositionX-CenterPositionX;
	local RelativeY = PositionY-CenterPositionY;
	local RotatedX = CenterPositionX+(RelativeX*math.cos(AngleInRadians)-RelativeY*math.sin(AngleInRadians));
	local RotatedY = CenterPositionY+(RelativeX*math.sin(AngleInRadians)+RelativeY*math.cos(AngleInRadians));
	return RotatedX, RotatedY;
end;
local function IsOffScreen(Frame)
	local Corners = {
		Frame.AbsolutePosition+Vector2.new(-Frame.AbsoluteSize.X/2, -Frame.AbsoluteSize.Y/2),
		Frame.AbsolutePosition+Vector2.new(Frame.AbsoluteSize.X/2, -Frame.AbsoluteSize.Y/2),
		Frame.AbsolutePosition+Vector2.new(Frame.AbsoluteSize.X/2, Frame.AbsoluteSize.Y/2),
		Frame.AbsolutePosition+Vector2.new(-Frame.AbsoluteSize.X/2, Frame.AbsoluteSize.Y/2),
	};
	for Int, Corner in ipairs(Corners) do
		local RotatedCornerX, RotatedCornerY = CalculateRotatedPosition(Corner.X, Corner.Y, Frame.AbsolutePosition.X, Frame.AbsolutePosition.Y, Frame.Rotation);
		if (RotatedCornerX <= 0 or RotatedCornerX >= Camera.ViewportSize.X) or (RotatedCornerY <= -236 or RotatedCornerY >= Camera.ViewportSize.Y) then
			return true;
		end;
	end;
	return false;
end;
local function IsOutOfBounds(Frame, BoundsFrame)
	local Corners = {
		Frame.AbsolutePosition+Vector2.new(-Frame.AbsoluteSize.X/2, -Frame.AbsoluteSize.Y/2),
		Frame.AbsolutePosition+Vector2.new(Frame.AbsoluteSize.X/2, -Frame.AbsoluteSize.Y/2),
		Frame.AbsolutePosition+Vector2.new(Frame.AbsoluteSize.X/2, Frame.AbsoluteSize.Y/2),
		Frame.AbsolutePosition+Vector2.new(-Frame.AbsoluteSize.X/2, Frame.AbsoluteSize.Y/2),
	};
	for Int, Corner in ipairs(Corners) do
		local RotatedCornerX, RotatedCornerY = CalculateRotatedPosition(Corner.X, Corner.Y, Frame.AbsolutePosition.X, Frame.AbsolutePosition.Y, Frame.Rotation);
		if (RotatedCornerX <= BoundsFrame.AbsolutePosition.X or RotatedCornerX >= BoundsFrame.AbsolutePosition.X+BoundsFrame.AbsoluteSize.X) or (RotatedCornerY <= BoundsFrame.AbsolutePosition.Y or RotatedCornerY >= BoundsFrame.AbsolutePosition.Y+BoundsFrame.AbsoluteSize.Y) then
			return true;
		end;
	end;
	return false;
end;

local function VerifyConfigs(Configs, DefaultConfigs)
	if Configs ~= DefaultConfigs then
		for Index, Value in pairs(Configs) do
			local Default = DefaultConfigs[Index];
			if Default ~= nil then
				if typeof(Value) == typeof(Default) then
					if typeof(Value) == "table" then
						if Index ~= "Properties" then
							if #Value > 0 then
								for Index2, Value2 in pairs(Default) do
									if Value[Index2] == nil then
										if typeof(Value[Index2]) == typeof(Value2) then
											continue;
										else
											warn(`Invalid config: {Index}, descendant: '{Index2}' is not a {typeof(Value2)} type.`);
											Configs[Index] = Default;
										end;
									else
										warn(`Invalid config: {Index}, descendant: '{Index2}' is not set.`);
										Configs[Index] = Default;
									end;
								end;
							end;
						end;
					end;
				else
					warn(`Invalid config: {Index}, is not a {typeof(Default)} type.`);
					Configs[Index] = Default;
				end;
			else
				warn(`Invalid config: '{tostring(Index)}'`);
				Configs[Index] = nil;
			end;
		end;
	end;
end;

local function EmitParticle(Parent, Configs)
	return coroutine.wrap(function()
		local Particle = Configs.Texture == "" and Instance.new("Frame") or Instance.new("ImageLabel");
		Particle.Name = "";
		Particle.Active = false;
		Particle.Selectable = false;
		Particle.AnchorPoint = Vector2.new(0.5, 0.5);
		Particle.ZIndex = 3000;
		Particle.AutomaticSize = Enum.AutomaticSize.None;
		Particle.Size = UDim2.new(0, Configs.Size.X, 0, Configs.Size.Y);
		Particle.Visible = true;
		Particle.SizeConstraint = Enum.SizeConstraint.RelativeXY;
		Particle.BorderColor3 = Color3.fromRGB(0, 0, 0);
		Particle.SelectionOrder = 0;
		Particle.LayoutOrder = 0;
		Particle.Rotation = 0;
		Particle.ClipsDescendants = false;
		if Configs.Texture == "" then
			Particle.BackgroundTransparency = 0;
			Particle.Position = UDim2.new(0, Configs.Position.X, 0, Configs.Position.Y);
			Particle.BorderMode = Enum.BorderMode.Outline;
			Particle.BorderSizePixel = 0;
			Particle.BackgroundColor3 = Color3.fromRGB(255, 255, 255);
			Particle.Style = Enum.FrameStyle.Custom;
		else
			Particle.BackgroundTransparency = 1;
			Particle.Position = UDim2.new(0, Configs.Position.X, 0, Configs.Position.Y);
			Particle.BorderMode = Enum.BorderMode.Outline;
			Particle.BorderSizePixel = 0;
			Particle.BackgroundColor3 = Color3.fromRGB(255, 255, 255);
			Particle.ImageColor3 = Color3.fromRGB(255, 255, 255);
			Particle.ScaleType = Enum.ScaleType.Stretch;
			Particle.ImageTransparency = 0;
			Particle.ResampleMode = Enum.ResamplerMode.Default;
			Particle.TileSize = UDim2.new(1, 0, 1, 0);
			Particle.ImageRectSize = Vector2.zero;
			Particle.SliceScale = 1;
			Particle.ImageRectOffset = Vector2.zero;
			Particle.Image = Configs.Texture;
			Particle.SliceCenter = Rect.new(Vector2.zero, Vector2.zero);
		end;
		for Property, Value in pairs(Configs.Properties) do
			Particle[Property] = Value;
		end;
		Particle.Parent = Parent;

		if TableLength(Configs.FadeIn) > 0 then
			VerifyConfigs(Configs.FadeIn, Module.DefaultConfigs.FadeIn);
			if TableLength(Configs.FadeIn.TweenProperties) > 0 then
				Tween(Particle, Configs.FadeIn.Duration, Configs.FadeIn.EasingStyle, Configs.FadeIn.EasingDirection, Configs.FadeIn.TweenProperties);
			end;
		end;

		local ParticleVelocity = Configs.Acceleration;
		local Iteration = 0;

		local Time = os.clock();
		local Signal = nil;
		Signal = RunService.Heartbeat:Connect(function()
			if Parent ~= nil and Particle ~= nil then
				ParticleVelocity /= Configs.FrictionCoefficient;
				ParticleVelocity += Configs.Gravity;
				Particle.Position += UDim2.fromOffset(ParticleVelocity.X, ParticleVelocity.Y);
				Iteration += 1;
				if Iteration > 20 and (Parent.ClassName == "ScreenGui" and IsOffScreen(Particle) or IsOutOfBounds(Particle, Parent)) == true then
					Particle:Destroy();
					Signal:Disconnect();
				end;
			else
				Signal:Disconnect();
			end;
		end);

		task.delay(Configs.LifeTime, function()
			if Parent ~= nil and Particle ~= nil then
				if TableLength(Configs.FadeOut) > 0 then
					VerifyConfigs(Configs.FadeOut, Module.DefaultConfigs.FadeOut);
					if TableLength(Configs.FadeOut.TweenProperties) > 0 then
						Tween(Particle, Configs.FadeOut.Duration, Configs.FadeOut.EasingStyle, Configs.FadeOut.EasingDirection, Configs.FadeOut.TweenProperties).Completed:Once(function()
							Signal:Disconnect();
							Particle:Destroy();
						end);
					else
						Signal:Disconnect();
						Particle:Destroy();
					end;
				else
					Signal:Disconnect();
					Particle:Destroy();
				end;
			end;
		end);

		return {
			["Particle"] = Particle,
		};
	end)();
end;

function Module.New()
	if RunService:IsClient() == true then
		local Player = Players.LocalPlayer;

		local Screen = Instance.new("ScreenGui");
		Screen.Name = NewGuid();
		Screen.IgnoreGuiInset = false;
		Screen.DisplayOrder = 3000;
		Screen.Parent = Player.PlayerGui;

		local self = {["ScreenGui"] = Screen};
		function self:Emit(Configs)
			if Screen == nil then
				return;
			end;
			Configs = Configs or Module.DefaultConfigs;
			VerifyConfigs(Configs, Module.DefaultConfigs);
			return EmitParticle(Screen, Configs);
		end;
		function self:EmitPreset(Preset, Configs)
			if Screen == nil then
				return;
			end;
			local PresetModule = require(script.Presets:FindFirstChild(Preset));
			Configs = Configs or PresetModule.DefaultConfigs;
			VerifyConfigs(Configs, PresetModule.DefaultConfigs);
			PresetModule.Emit(function(Configs)
				return EmitParticle(Screen, Configs);
			end, Configs);
		end;
		return self;
	else
		warn("'UIEmitter.New()' should be ran in a local-script. Use 'UIEmitter.From()' instead.");
	end;
end;
function Module.From(GuiObject)
	local Frame = Instance.new("Frame");
	Frame.Name = NewGuid();
	Frame.ZIndex = 3000;
	Frame.Size = UDim2.new(1, 0, 1, 0);
	Frame.Position = UDim2.fromOffset(0, 0)
	Frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255);
	Frame.BorderColor3 = Color3.fromRGB(0, 0, 0);
	Frame.ClipsDescendants = true;
	Frame.BackgroundTransparency = 1;
	Frame.BorderSizePixel = 0;
	Frame.Parent = GuiObject;

	local self = {["Frame"] = Frame};
	function self:Emit(Configs)
		if GuiObject == nil then
			return;
		end;
		Configs = Configs or Module.DefaultConfigs;
		VerifyConfigs(Configs, Module.DefaultConfigs);
		return EmitParticle(Frame, Configs);
	end;
	function self:EmitPreset(Preset, Configs)
		if Frame == nil then
			return;
		end;
		local PresetModule = require(script.Presets:FindFirstChild(Preset));
		Configs = Configs or PresetModule.DefaultConfigs;
		VerifyConfigs(Configs, PresetModule.DefaultConfigs);
		PresetModule.Emit(function(Configs)
			return EmitParticle(Frame, Configs);
		end, Configs);
	end;
	return self;
end;
return Module;

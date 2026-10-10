--!strict

--// Generator for fence ProceduralModels. Size.X/Z is the fenced footprint, Size.Y the post height
--// Sides follow the model's NormalIds: Front = -Z, Back = +Z, Left = -X, Right = +X

type Attributes = {
	PostSpacing: number,
	PostWidth: number,
	PostColor: Color3,
	RailCount: number,
	RailThickness: number,
	RailHeight: number,
	RailColor: Color3,
	CornerOverhang: number,
	OpeningSide: Enum.NormalId,
	OpeningWidth: number,
	OpeningOffset: number,
	MakePlotArea: boolean,
	PlotAreaInset: number,
	PlotAreaHeight: number,
}

type GenerationParams = {
	Attributes: Attributes,
	Size: Vector3,
	Pause: (self: GenerationParams) -> (),
}

type Side = {
	normal: Enum.NormalId,
	from: Vector3,
	to: Vector3,
	axis: Vector3,
}

const MIN_DIMENSION = 0.05

const defaultAttributes: Attributes = {
	PostSpacing = 8,
	PostWidth = 1,
	PostColor = Color3.fromRGB(102, 75, 58),
	RailCount = 2,
	RailThickness = 0.5,
	RailHeight = 1,
	RailColor = Color3.fromRGB(124, 92, 70),
	CornerOverhang = 0.5,
	OpeningSide = Enum.NormalId.Left, --// Top/Bottom mean no opening
	OpeningWidth = 12,
	OpeningOffset = 0, --// Along the side, from its centre
	MakePlotArea = false,
	PlotAreaInset = 2, --// From each footprint edge
	PlotAreaHeight = 1,
}

local function createPart(name: string, color: Color3, size: Vector3, cframe: CFrame, parent: Instance): Part
	const part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CastShadow = false
	part.Color = color
	part.Material = Enum.Material.Plastic
	part.TopSurface = Enum.SurfaceType.Studs
	part.BottomSurface = Enum.SurfaceType.Studs
	part.FrontSurface = Enum.SurfaceType.Studs
	part.BackSurface = Enum.SurfaceType.Studs
	part.LeftSurface = Enum.SurfaceType.Studs
	part.RightSurface = Enum.SurfaceType.Studs
	part.Size = size
	part.CFrame = cframe
	part.Parent = parent
	return part
end

--// Invisible PlotArea part resting on the fence base, inset from the footprint
local function createPlotArea(attributes: Attributes, size: Vector3, container: Instance)
	const inset = math.max(attributes.PlotAreaInset, 0)
	const height = math.max(attributes.PlotAreaHeight, MIN_DIMENSION)

	const area = Instance.new("Part")
	area.Name = "PlotArea"
	area.Anchored = true
	area.CanCollide = false
	area.CastShadow = false
	area.Transparency = 1
	area.Size = Vector3.new(
		math.max(size.X - inset * 2, MIN_DIMENSION),
		height,
		math.max(size.Z - inset * 2, MIN_DIMENSION)
	)
	area.CFrame = CFrame.new(0, -size.Y / 2 + height / 2, 0)
	area.Parent = container
end

--// Rail centre heights above the fence base, evenly spaced between the bottom and top rail
local function getRailHeights(attributes: Attributes, postHeight: number): { number }
	const count = math.max(0, math.floor(attributes.RailCount))
	const topY = postHeight - attributes.RailHeight
	const bottomY = attributes.RailHeight * 1.5
	if count == 1 then
		return { topY }
	end

	const heights = {}
	for i = 0, count - 1 do
		table.insert(heights, bottomY + (topY - bottomY) * i / (count - 1))
	end
	return heights
end

local function onGenerate(parameters: GenerationParams, container: Instance)
	const attributes = parameters.Attributes
	const size = parameters.Size
	const postWidth = math.max(attributes.PostWidth, MIN_DIMENSION)
	const spacing = math.max(attributes.PostSpacing, postWidth)
	const baseY = -size.Y / 2
	const halfX = size.X / 2 - postWidth / 2
	const halfZ = size.Z / 2 - postWidth / 2
	const railHeights = getRailHeights(attributes, size.Y)
	const cornerExtension = postWidth / 2 + attributes.CornerOverhang

	if attributes.MakePlotArea then
		createPlotArea(attributes, size, container)
	end

	const frontLeft = Vector3.new(-halfX, 0, -halfZ)
	const frontRight = Vector3.new(halfX, 0, -halfZ)
	const backRight = Vector3.new(halfX, 0, halfZ)
	const backLeft = Vector3.new(-halfX, 0, halfZ)

	const sides: { Side } = {
		{ normal = Enum.NormalId.Front, from = frontLeft, to = frontRight, axis = Vector3.xAxis },
		{ normal = Enum.NormalId.Right, from = frontRight, to = backRight, axis = Vector3.zAxis },
		{ normal = Enum.NormalId.Back, from = backRight, to = backLeft, axis = Vector3.xAxis },
		{ normal = Enum.NormalId.Left, from = backLeft, to = frontLeft, axis = Vector3.zAxis },
	}

	const posts = Instance.new("Folder")
	posts.Name = "Posts"
	posts.Parent = container
	const rails = Instance.new("Folder")
	rails.Name = "Rails"
	rails.Parent = container

	const placedPosts: { [string]: boolean } = {}
	local function addPost(position: Vector3)
		const key = string.format("%.3f,%.3f", position.X, position.Z)
		if placedPosts[key] then
			return
		end
		placedPosts[key] = true
		createPart(
			"Post",
			attributes.PostColor,
			Vector3.new(postWidth, size.Y, postWidth),
			CFrame.new(position.X, 0, position.Z),
			posts
		)
	end

	--// A run is a straight stretch between two posts, corner ends get the rail overhang
	local function addRun(from: Vector3, to: Vector3, isFromCorner: boolean, isToCorner: boolean)
		const length = (to - from).Magnitude
		if length < postWidth then
			return
		end

		const spans = math.max(1, math.round(length / spacing))
		for i = 0, spans do
			addPost(from:Lerp(to, i / spans))
		end

		const direction = (to - from).Unit
		const fromExtension = if isFromCorner then cornerExtension else 0
		const toExtension = if isToCorner then cornerExtension else 0
		const railLength = length + fromExtension + toExtension
		const centre = (from + to) / 2 + direction * ((toExtension - fromExtension) / 2)
		for _, height in railHeights do
			createPart(
				"Rail",
				attributes.RailColor,
				Vector3.new(math.max(attributes.RailThickness, MIN_DIMENSION), math.max(attributes.RailHeight, MIN_DIMENSION), railLength),
				CFrame.lookAlong(Vector3.new(centre.X, baseY + height, centre.Z), direction),
				rails
			)
		end
	end

	for _, side in sides do
		parameters:Pause()

		if side.normal ~= attributes.OpeningSide or attributes.OpeningWidth <= 0 then
			addRun(side.from, side.to, true, true)
			continue
		end

		--// Posts sit flush against the opening edges
		const sideLength = (side.to - side.from).Magnitude
		const direction = (side.to - side.from).Unit
		const openingCentre = (side.from + side.to) / 2 + side.axis * attributes.OpeningOffset
		const centreT = (openingCentre - side.from):Dot(direction)
		const startT = math.clamp(centreT - attributes.OpeningWidth / 2 - postWidth / 2, 0, sideLength)
		const endT = math.clamp(centreT + attributes.OpeningWidth / 2 + postWidth / 2, 0, sideLength)

		addRun(side.from, side.from + direction * startT, true, false)
		addRun(side.from + direction * endT, side.to, false, true)
	end
end

return {
	Attributes = defaultAttributes,
	OnGenerate = onGenerate,
}

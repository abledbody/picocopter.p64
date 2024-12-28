local Transform = require"blade3d.transform"
local quat = require"blade3d.quaternions"

---Creates a projection matrix.
---@param n number The depth of the near clipping plane.
---@param f number The depth of the far clipping plane.
---@param s number The slope of the field of view. `-sin(fov*0.5)/cos(fov*0.5)` if FOV is in revolutions.
---@param a number The aspect ratio of the screen, as width/height.
---@return userdata @A 4x4 projection matrix.
local function project(n,f,s,a)
	local d = n-f
	local mat = userdata("f64",4,4)
	-- Note: blade3d uses reverse depth, which means that the near plane is at
	-- 0, and the far plane is at 1.
	mat:set(0,0,
		  s,  0,  0, 0,
		  0,s*a,  0, 0,
		  0,  0,1/d,-1,
		  0,  0,n/d, 0
	)
	return mat
end

---Converts a field of view in degrees to a slope.
---@param fov_degrees number The field of view in degrees.
---@return number @The slope of the field of view.
local function get_fov_slope(fov_degrees)
	local fov_angle = (0.5-fov_degrees/360)*0.5
	return -sin(fov_angle)/cos(fov_angle)
end

local function get_frustum_normals(fov_slope,aspect_ratio)
	local frust_norm_x = vec(fov_slope,-1)
	local frust_norm_y = frust_norm_x:mul(aspect_ratio,false,0,0,1)
	frust_norm_x /= frust_norm_x:magnitude()
	frust_norm_y /= frust_norm_y:magnitude()
	return frust_norm_x,frust_norm_y
end

---@class RenderCamera
---@field position userdata The XYZ coordinates of the camera position.
---@field rotation userdata The quaternion of the camera rotation.
---@field near_plane number The depth of the near clipping plane.
---@field far_plane number The depth of the far clipping plane.
---@field fov_slope number The slope of the field of view.
---@field target userdata The display target to render to.
---@field aspect_ratio number The aspect ratio of the display target.
---@field cts_add userdata The offset used for converting clip space to screen space.
---@field cts_mul userdata The multiplier used for converting clip space to screen space.
---@field view_matrix userdata A cached view matrix.
---@field vp_matrix userdata A cached view-projection matrix.
---@field frust_norm_x userdata The normal of the left frustum plane.
---@field frust_norm_y userdata The normal of the top frustum plane.
local m_camera = {
	set_fov_degrees = function(self,fov_degrees)
		self:set_fov_slope(get_fov_slope(fov_degrees))
	end,
	
	set_fov_slope = function(self,fov_slope)
		self.frust_norm_x,self.frust_norm_y = get_frustum_normals(fov_slope,self.aspect_ratio)
		self.fov_slope = fov_slope
		self.vp_matrix = nil
	end,
	
	set_near_plane = function(self,near)
		self.near_plane = near
		self.vp_matrix = nil
	end,
	
	set_far_plane = function(self,far)
		self.far_plane = far
		self.vp_matrix = nil
	end,
	
	---Triggers a recalculation of several properties that depend on the display target.
	refresh_viewport = function(self)
		local width,height = self.target:width(),self.target:height()
		self.aspect_ratio = width/height
		self.cts_add = vec(width,height,width)*0.5
		self.cts_mul = vec(width,-height,-width)*0.5
		self.vp_matrix = nil
	end,
	
	set_target = function(self,target)
		self.target = target
		self:refresh_viewport()
	end,
	
	---@param pos userdata The XYZ coordinates of the camera position.
	---@param rot userdata The quaternion of the camera rotation.
	set_transform = function(self,pos,rot)
		self.position,self.rotation = pos,rot
		self.view_matrix,self.vp_matrix = nil,nil
	end,
	
	---@returns userdata The view matrix of the camera. Uses a cached value if valid.
	get_view_matrix = function(self)
		if self.view_matrix then return self.view_matrix end
		
		self.view_matrix = Transform.translate(self.position*-1)
			:matmul3d(quat.mat(self.rotation):transpose())
		
		return self.view_matrix
	end,
	
	---@returns userdata The view-projection matrix of the camera. Uses a cached value if valid.
	get_vp_matrix = function(self)
		if self.vp_matrix then return self.vp_matrix end
		
		self.vp_matrix = self:get_view_matrix():matmul(
			project(self.near_plane,self.far_plane,self.fov_slope,self.aspect_ratio)
		)
		
		return self.vp_matrix
	end,
}
m_camera.__index = m_camera

---@param near_plane number The depth of the near clipping plane.
---@param far_plane number The depth of the far clipping plane.
---@param fov_slope number The slope of the field of view. Use `get_fov_slope` if you want to convert from degrees.
---@param target userdata The display target to render to. Defaults to the main display.
---@param position? userdata The XYZ coordinates of the camera position. Defaults to origin.
---@param rotation? userdata The quaternion of the camera rotation. Defaults to identity.
---@return RenderCamera @A new camera object.
local function new(near_plane,far_plane,fov_slope,target,position,rotation)
	local width,height = target:width(),target:height()
	
	local o = setmetatable(
		{
			position = position or vec(0,0,0),
			rotation = rotation or vec(0,0,0,1),
			near_plane = near_plane,
			far_plane = far_plane,
			fov_slope = fov_slope,
			target = target,
			aspect_ratio = width/height,
			cts_add = vec(width,height,width)*0.5,
			cts_mul = vec(width,-height,-width)*0.5,
			view_matrix = nil,
			vp_matrix = nil,
		},
		m_camera
	)
	
	o.frust_norm_x,o.frust_norm_y = get_frustum_normals(fov_slope,o.aspect_ratio)
	
	return o
end

return {
	new = new,
	project = project,
	get_fov_slope = get_fov_slope,
}
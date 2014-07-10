
AddCSLuaFile()
 
DEFINE_BASECLASS( "base_anim" )
 
ENT.PrintName   = "Lift"
ENT.Author      = "Lex Robinson"
ENT.Information = "Will this work? I doubt it"
ENT.Category    = "Lex's Dev Stuff"
 
ENT.Editable    = false
ENT.Spawnable   = true
ENT.AdminOnly   = false
ENT.RenderGroup = RENDERGROUP_TRANSALPHA
 
function ENT:SpawnFunction( ply, tr, ClassName )
 
        if ( not tr.Hit ) then return end
 
        local SpawnPos = tr.HitPos + tr.HitNormal * 10;
 
        local ent = ents.Create( ClassName )
        ent:SetPos( SpawnPos )
        ent:Spawn()
        ent:Activate()
 
        return ent
end
 
function ENT:Initialize()
 
        if ( SERVER ) then
 
                self:SetModel("models/hunter/plates/plate1x1.mdl");
                self:PhysicsInit(SOLID_VPHYSICS);
                self:SetMoveType(MOVETYPE_VPHYSICS);
                self:SetSolid(SOLID_VPHYSICS);
 
                self:GetPhysicsObject():Wake();
 
        else
 
                self.ents = {
                        -- self
                };
 
                -- woo debug
                g_Liftus = self;
 
        end
 
end
 
if (SERVER) then return; end
 
function ENT:AddEnt(ent)
        table.insert(self.ents, ent);
end
 
concommand.Add("liftify", function(ply)
        local ent = ply:GetEyeTrace().Entity;
        if (IsValid(ent) and IsValid(g_Liftus)) then
                g_Liftus:AddEnt(ent);
        end
end)
 
-- TY Jinto! http://facepunch.com/showthread.php?t=1205832&p=37280318&viewfull=1#post37280318
 
function ENT:DrawMask( wx, wy )
 
        local p = self:GetPos();
        local z = self:GetUp();
        local y = self:GetForward();
        local x  = self:GetRight();
 
        local segments = 4;
 
 
        render.SetColorMaterial();
 
 
        mesh.Begin( MATERIAL_QUADS, segments );
 
        local base = p + z * -0.5;
        local a = base + (-y * wy) + (-x * wx);
        local b = base + ( y * wy) + (-x * wx);
        local c = base + ( y * wy) + ( x * wx);
        local d = base + (-y * wy) + ( x * wx);
 
        mesh.Quad(a, b, c, d);
 
        mesh.End();
 
end
 
local mat = Material("phoenix_storms/cube");
-- local mat = Material("models/wireframe");
-- local mat = Material("models/props_c17/paper01");
 
function ENT:DrawInterior(wx, wy)
 
        local p = self:GetPos();
        local z = self:GetUp();
        local y = self:GetForward();
        local x  = self:GetRight();
 
        local size = 20;
 
        render.SetMaterial(mat);
        render.SuppressEngineLighting(true);
 
        local base, a, b, c, d;
 
        local zd = wx;
 
        mesh.Begin(MATERIAL_QUADS, 36);
 
        local function point(x, y, z, u, v)
                mesh.Position(base + x + y + z);
                mesh.TexCoord(0, u, v);
                mesh.AdvanceVertex();
        end
 
        local doorDepth = 10;
 
        -- Doorway
        do
                local x, y, z = x * wx, y * wy, z * doorDepth;
                base = p - z;
 
                -- Bottom
                point(-x,  y, -z, 1, 0.2);
                point(-x,  y,  z, 1, 0  );
                point( x,  y,  z, 0, 0  );
                point( x,  y, -z, 0, 0.2);
 
                -- Left
                point( x,  y, -z, 0.2, 1);
                point( x,  y,  z, 0,   1);
                point( x, -y,  z, 0,   0);
                point( x, -y, -z, 0.2, 0);
 
                -- Top
                point( x, -y, -z, 0, 0.2);
                point( x, -y,  z, 0, 0  );
                point(-x, -y,  z, 1, 0  );
                point(-x, -y, -z, 1, 0.2);
 
                -- Right
                point(-x, -y, -z, 0.2, 0);
                point(-x, -y,  z, 0,   0);
                point(-x,  y,  z, 0,   1);
                point(-x,  y, -z, 0.2, 1);
        end
 
        -- Interior
        local interiorDepth = 60;
        local interiorWidth = wx * 2;
        do
                base = base - z * doorDepth - z * interiorDepth;
                local x, y, z = x * interiorWidth, y * wy, z * interiorDepth;
                -- Bottom
                point(-x,  y, -z,  1.5, 1);
                point(-x,  y,  z,  1.5, 0.2);
                point( x,  y,  z, -0.5, 0.2);
                point( x,  y, -z, -0.5, 1);
                -- Left
                point( x,  y, -z, 1,   1);
                point( x,  y,  z, 0.2, 1);
                point( x, -y,  z, 0.2, 0);
                point( x, -y, -z, 1,   0);
                -- Top
                point( x, -y, -z, -0.5, 1);
                point( x, -y,  z, -0.5, 0.2);
                point(-x, -y,  z,  1.5, 0.2);
                point(-x, -y, -z,  1.5, 1);
                -- Right
                point(-x, -y, -z, 1,   0);
                point(-x, -y,  z, 0.2, 0);
                point(-x,  y,  z, 0.2, 1);
                point(-x,  y, -z, 1,   1);
                -- Back
                point(-x,  y, -z, -0.5, 1);
                point( x,  y, -z,  1.5, 1);
                point( x, -y, -z,  1.5, 0);
                point(-x, -y, -z, -0.5, 0);
        end
 
        mesh.End()
        for i, ent in ipairs(self.ents) do
                if (IsValid(ent)) then
                        ent:DrawModel();
                else
                        table.remove(self.ents, i);
                end
        end
 
        render.SuppressEngineLighting(false);
 
end
 
 
function ENT:DrawOverlay()
 
        -- self:DrawModel();
end
 
 
function ENT:Draw()
 
        render.SetBlend(0.9);
 
        self:DrawModel();
 
        render.SetBlend(1);
 
        render.ClearStencil();
        render.SetStencilEnable( true );
        render.SetStencilCompareFunction( STENCIL_ALWAYS );
        render.SetStencilPassOperation( STENCIL_REPLACE );
        render.SetStencilFailOperation( STENCIL_KEEP );
        render.SetStencilZFailOperation( STENCIL_KEEP );
        render.SetStencilWriteMask( 1 );
        render.SetStencilTestMask( 1 );
        render.SetStencilReferenceValue( 1 );
 
        local wx, wy = 45, 55;
 
        self:DrawMask( wx, wy );
 
        render.SetStencilCompareFunction( STENCIL_EQUAL );
 
        -- clear the inside of our mask so we have a nice clean slate to draw in.
        render.ClearBuffersObeyStencil( 0, 0, 0, 0, true );
 
        self:DrawInterior( wx, wy );
 
        render.SetStencilEnable( false );
 
        self:DrawOverlay();
 
end
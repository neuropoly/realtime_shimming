function [b0final] = SWFM(complVol, TE)
% SWFM computes c0 fieldmaps based on "Selective-Weighted-Field-Mapping"
% method.
%
% _SYNTAX_
% 
% [b0] = SWFM(complVol, TE)
%
% _DESCRIPTION_
%
% _INPUT ARGUMENTS_
%
%    complVol
%      complex 4D data set complVol(x,y,z,t)
%    TE
%      array of TEs in [s]
%
% _OUTPUTS_
%
%   b0
%     field map in units of Hz 
% 

gamma = 267.52218744 * 10^6; % rad*Hz/Tesla
factor= 1./(gamma.*pi.*TE(end));
            
% create magnitude and phase data volumes
mag_data = abs(complVol);
ph_data = angle(complVol);
figure(20); imagesc(mag_data(:,:,1,1));
figure(21); imagesc(ph_data(:,:,1,1));

X=[];
for t=1:length(TE)
    X(:,:,:,t)= mag_data(:,:,:,t).*exp(1i*ph_data(:,:,:,t));
end


% SDQWF correspond au "Signal Decay Quality Weighting Factor"
% FM repr�sente la fraction de la magnitude de l'�cho j par rapport � la
% somme des magnitudes.
% FB repr�sente la fraction inverse du bruit de l'�cho j par rapport � la
% somme des bruits du signal.

% Calcul du facteur FM 
magtotal=zeros( size(mag_data,1), size(mag_data,2), size(mag_data,3)  );
FM=zeros(size(mag_data));
for t=1:length(TE)
    magtotal(:,:,:)=magtotal(:,:,:)+mag_data(:,:,:,t);
end
for t=1:length(TE)
    FM(:,:,:,t)=mag_data(:,:,:,t)./magtotal;
end

    % Calcul du facteur FB pr�sent dans la fonction arctangente � 4 cadrants
sigma=zeros( size(mag_data)  );
FB=zeros(size(mag_data));
sigmatot=zeros( size(mag_data,1), size(mag_data,2), size(mag_data,3)  );
for t=1:length(TE)
    sigma(:,:,:,t) = stdfilt(mag_data(:,:,:,t));
end
for t=1:length(TE)
    sigmatot(:,:,:)=sigmatot(:,:,:) + sigma(:,:,:,t);
end
for t =1:length(TE) 
    FB(:,:,:,t)=sigmatot./sigma(:,:,:,t);
end


% Calcul du facteur SDQWF
SDQWF=zeros(size(mag_data));
for t=1:length(TE)
    SDQWF(:,:,:,t)=FM(:,:,:,t).*FB(:,:,:,t);
end
    
% Calcul du facteur produit X1Xj pr�sent dans la fonction arctangente � 4 cadrants
X1X_T=[];
for t=1:length(TE)
    X1X_T(:,:,:,t)= mag_data(:,:,:,1).*mag_data(:,:,:,t).*exp(1i*(ph_data(:,:,:,1)+ph_data(:,:,:,t)));
end

% Calcul du facteur somme pr�sent dans la fonction arctangente � 4 cadrants        
sommable=zeros(size(complVol));
somme=zeros( size(complVol,1),size(complVol,2) ,size(complVol,3) );
cond1 = zeros( size(complVol) );
cond2 = zeros( size(complVol) );
cond3 = zeros( size(complVol) );
cond4 = zeros( size(complVol) );
cond5 = zeros( size(complVol) );

for t = 1:length(TE)
    cond1(:,:,:,t) = real(X1X_T(:,:,:,t))>0 ;
    cond2(:,:,:,t) = real(X1X_T(:,:,:,t))<0 & imag(X1X_T(:,:,:,t))~=0 ;
    cond3(:,:,:,t) = real(X1X_T(:,:,:,t))>0 & imag(X1X_T(:,:,:,t))==0 ;
    cond4(:,:,:,t) = real(X1X_T(:,:,:,t))<0 & imag(X1X_T(:,:,:,t))==0 ;
    cond5(:,:,:,t) = real(X1X_T(:,:,:,t))==0 & imag(X1X_T(:,:,:,t))==0 ;
    for i= 1:size(complVol,1) 
        for j= 1:size(complVol,2)
            for k= 1: size(complVol,3)
                if cond1(i,j,k,t)==1
                     sommable(i,j,k,t) = (imag(X1X_T(i,j,k,t)).*SDQWF(i,j,k,t))./(sqrt( (imag(X1X_T(i,j,k,t))).^2 + (real(X1X_T(i,j,k,t))).^2 ) +real(X1X_T(i,j,k,t)) );
                elseif cond2(i,j,k,t)==1
                    sommable(i,j,k,t) = ((sqrt((imag( X1X_T(i,j,k,t) ) ).^2 + (real(X1X_T(i,j,k,t))).^2 ) - real(X1X_T(i,j,k,t))) .*SDQWF(i,j,k,t))./(imag(X1X_T(i,j,k,t)));
                elseif cond3(i,j,k,t)==1
                    sommable(i,j,k,t)=0;
                elseif cond4(i,j,k,t)==1
                    sommable(i,j,k,t)=0;
                elseif cond5(i,j,k,t)==1
                    sommable(i,j,k,t)=0;
                end
            end
        end
    end
end
                    

for t=1:length(TE)
    somme(:,:,:) = somme(:,:,:) + sommable(:,:,:,t);
end

b01(:,:,:) = factor.*atan(somme); % [rad*Hz]
b01 = b01/(2*pi); % [Hz]
figure(22); imagesc(b01);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% % Somme n'a pas que des valeurs comprises entre 180 et -180 degr�s. Il faut
% % faire en sorte que ce soit le cas ?! 
% for i = 1 : size( somme, 1 )
%     for j = 1 : size( somme, 2 )
%         for k = 1 : size( somme, 3 )
%             if somme(i,j,k)>180 
%                 while somme(i,j,k)>180
%                     somme(i,j,k)=somme(i,j,k)-180;
%                 end
%             elseif somme(i,j,k)<-180 
%                 while somme(i,j,k)<-180
%                     somme(i,j,k)=somme(i,j,k)+180;
%                 end
%             end
%         end
%     end
% end
b02(:,:,:) = factor.*atan(somme); % [rad*Hz]
b02 = b02/(2*pi); % [Hz]
figure(23); imagesc(b02);

b03(:,:,:) = b02-b01; % [rad*Hz]
b03 = b03/(2*pi); % [Hz]
figure(24); imagesc(b03);

% Je poss�de des valeurs d'angle donn�e par "somme". Or, la fonction atan2
% � 4 quadrants prend en entr�es la partie imaginaire Y et la partie 
% r�elle du nombre complexe dont l'angle est somme. De plus, on va 
% imposer que la norme soit �gale � 1.

% Attention !! Les angles donn�s par somme sont des angles en degr�s ?! 
Xco=zeros( size(somme,1) , size(somme,2) , size(somme,3)  );
Yco=zeros( size(somme,1) , size(somme,2) , size(somme,3)  );
for i=1:size(somme,1)
    for j=1:size(somme,2)
        for k=1:size(somme,3)
            if somme(i,j,k)< 90 && somme(i,j,k)>0
                Xco(i,j,k)=1./(sqrt(1+(tan(somme(i,j,k))).^2));
                Yco(i,j,k)=sqrt( (( tan( somme(i,j,k) ) ).^2)./(1 + ( tan( somme(i,j,k) ) ).^2));
            elseif somme(i,j,k)> 90
                Xco(i,j,k)=-1./(sqrt(1+(tan(somme(i,j,k))).^2));
                Yco(i,j,k)=sqrt( (( tan( somme(i,j,k) ) ).^2)./(1 + ( tan( somme(i,j,k) ) ).^2));
            elseif somme(i,j,k)> -90 && somme(i,j,k)<0
                Xco(i,j,k)=1./(sqrt(1+(tan(somme(i,j,k))).^2));
                Yco(i,j,k)=-sqrt( (( tan( somme(i,j,k) ) ).^2)./(1 + ( tan( somme(i,j,k) ) ).^2));
            elseif somme(i,j,k)< -90
                Xco(i,j,k)=-1./(sqrt(1+(tan(somme(i,j,k))).^2));
                Yco(i,j,k)=-sqrt( (( tan( somme(i,j,k) ) ).^2)./(1 + ( tan( somme(i,j,k) ) ).^2));
            elseif somme==0
                Xco = 1 ;
                Yco = 0 ;
            elseif somme==90
                Xco = 0 ;
                Yco = 1 ;
            elseif somme==-90
                Xco = 0 ;
                Yco = -1 ;
            elseif somme==180 || somme==-180
                Xco = -1 ;
                Yco = 0 ;
            end
        end
    end
end

    
b0final(:,:,:) = factor.*atan2(Yco,Xco); % [rad*Hz]
b0final = b0final/(2*pi); % [Hz]



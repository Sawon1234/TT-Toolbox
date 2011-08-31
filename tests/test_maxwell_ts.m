dphys = 1;

N = 128;
d0t = 10;

T = 5;
b = 10;
alpha = 0.5;

eps = 1e-12;
tol = 1e-8;

Tsplit = [0, 0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10];
d0ts =   [  5,    6,    6,    7,   8,   9,  10, 11,11,12];

scheme = 'euler';
% scheme = 'CN';

% solv = 'ts';
solv = 'global';

plt = 1;

gamma = 4/b;

tau = T/(2^d0t);
d0x = log2(N);

%%%%
if (dphys==1)
%     [D1,x]=spectral_chebdiff(N-1, -sqrt(b), sqrt(b));
%     [x,cw]=fclencurt(N, -sqrt(b), sqrt(b));
%     [x,cw] = ffejer2(N, -sqrt(b), sqrt(b));
    [x,cw]=lgwt(N, -sqrt(b), sqrt(b));
    D1 = lagr_diff(x);
    
    W = (1-(x.^2)/b); % .^(b/2); % FENE
%     W = max(W, 1e-6);
    V = -1*sqrt(2).*x; % Velocity
%     V = 0;
    u = W.^(b/2-2);
    
%     Mass = lagrange_bilin(x, cw, W.^gamma, eye(N), eye(N));
%     G2 = lagrange_bilin(x, cw, W, D1, D1*diag(W.^(gamma-1)));
%     S1 = lagrange_bilin(x, cw, (W.^gamma).*V, D1, eye(N));    
%     Mass = diag(W.^2);
    Mass = lagrange_bilin(x, cw, W.^2, eye(N), eye(N));
    G2 = lagrange_bilin(x, cw, ones(N,1), D1, D1*diag(W.^2));    
%     G2 = -D1^2*diag(W.^2);
    S1 = lagrange_bilin(x, cw, V.*(W.^2)+alpha*x.*W, D1, eye(N));    
%     S1 = D1*diag(-V.*(W.^2)-alpha*x.*W);
    
    Stiff = G2*alpha + S1;    

    tt_Stiff = full_to_nd(Stiff, eps);
    tt_Stiff = tt_matrix(tt_Stiff);
    tt_Mass = full_to_nd(Mass, eps);
    tt_Mass = tt_matrix(tt_Mass);

    ttu = full_to_qtt(u, tol);
end;

if (dphys==2)
    % Polar FENE model
%     [Dr,r]=spectral_chebdiff(N-1, 0, sqrt(b));    
%     [r,cwr]=fclencurt(N, 0, sqrt(b));
    [r,cwr]=ffejer2(N, 0, sqrt(b));
    Dr = lagr_diff(r);
    [D2th, th]=spectral_lap_pc(N);
    [Dth, th]=spectral_diff_pc(N);
    
    Wr = (1-(r.^2)/b); % FENE weight
%     Wr = max(Wr, 1e-8);
%     Wr = ones(N,1);    
%     u = kron(ones(N,1), Wr.^2);
    u = ones(N^2,1);
    % Flow
%     V1r = 0*r; V1th = 0*th;
    V2r = -1*sqrt(2)*r; V2th = sin(th);
        
    Mass_r = sparse(lagrange_bilin(r, cwr, (Wr.^2).*r, eye(N), eye(N)));
    Mass_th = speye(N);
%     St_rr = lagrange_bilin(r,cwr,Wr.*r.*r,Dr,Dr) - lagrange_bilin(r,cwr,Wr.*r,eye(N),Dr);
%     St_rr = lagrange_bilin(r,cwr,Wr,Dr,Dr) - lagrange_bilin(r,cwr,Wr./r,eye(N),Dr);
    G2_rr = lagrange_bilin(r, cwr, Wr.*r, Dr, Dr*diag(Wr.^2));
%     St_rr(N,:)=Dr(N,:);
%     Mass_rth = sparse(lagrange_bilin(r,cwr,Wr.*[1./r(1:N-1); 0],eye(N),eye(N)));
    Mass_rth = sparse(lagrange_bilin(r,cwr,(Wr.^2)./r,eye(N),eye(N)));
    G2_thth = -D2th;
%     G2_thth = Dth'*Dth;

    % Everythg sucks below vvv

    S1r = lagrange_bilin(r,cwr,(Wr.^2).*r.*V2r + alpha*r.*Wr, Dr, eye(N));
    S1th = diag(sin(th).*V2th);
    S2r = lagrange_bilin(r, cwr, Wr.*V2r + alpha*x.*W, eye(N), eye(N));
    S2th = -Dth*diag(cos(th).*V2th);
    
    St2 = kron(Mass_th, G2_rr) + kron(G2_thth, Mass_rth);
    Mass2 = kron(Mass_th, Mass_r);
    
    tt_Mass_r = tt_matrix(full_to_nd(full(Mass_r), eps));
    tt_Mass_th = tt_matrix(full_to_nd(full(Mass_th), eps));
    tt_G2_rr = tt_matrix(full_to_nd(G2_rr, eps));
    tt_G2_thth = tt_matrix(full_to_nd(G2_thth, eps));
    tt_Mass_rth = tt_matrix(full_to_nd(full(Mass_rth), eps));
    
    tt_S1r = tt_matrix(full_to_nd(S1r, eps));
    tt_S1th = tt_matrix(full_to_nd(S1th, eps));
    tt_S2r = tt_matrix(full_to_nd(S2r, eps));
    tt_S2th = tt_matrix(full_to_nd(S2th, eps));
    tt_S = kron(tt_S1r,tt_S1th)+kron(tt_S2r,tt_S2th);
    
    tt_Stiff = kron(tt_G2_rr,tt_Mass_th)+kron(tt_Mass_rth,tt_G2_thth);

    tt_Stiff = tt_Stiff*alpha + tt_S;
    tt_Stiff = round(tt_Stiff, eps);
    
    tt_Mass = kron(tt_Mass_r, tt_Mass_th);
    
    ttu = full_to_qtt(u, tol);
    
    x = kron(cos(th), r);
    y = kron(sin(th), r);
   
    % rhs = rhs.*r!!!!!
end;

if (strcmp(solv, 'ts'))
    % Timestep
    if (strcmp(scheme, 'euler'))
        % Euler scheme
        tt_tmm = core(tt_Mass);  % + 0e-14*tt_matrix(tt_eye(2,dphys*log2(N)))
        tt_tmp = tt_Mass + tt_Stiff*tau;
        tt_tmp = round(tt_tmp, eps); % + 0e-14*tt_matrix(tt_eye(2,dphys*log2(N))
        tt_tmp = core(tt_tmp);
    else
        %Cranck-Nicolson
        tt_tmm = tt_Mass - tt_Stiff*tau*0.5;
        tt_tmp = tt_Mass + tt_Stiff*tau*0.5;
        tt_tmm = core(round(tt_tmm, eps));
        tt_tmp = core(round(tt_tmp, eps));
    end;       
%     tt_tmp2 = tt_mat_compr(tt_mm(tt_transp(tt_tmp),tt_tmp), eps);
       
    results = zeros(2^d0t, 2);
    solt0 = tic;
    for t=1:2^d0t
        ushf = tt_mvk3(tt_tmm, ttu, tol, 'verb', 0);
%         ushf = tt_mvk3(tt_transp(tt_tmp), ushf, tol, 'verb', 0);
        ttu = dmrg_solve2(tt_tmp, ushf, tol, 'verb', 1, 'x0', ttu, 'max_full_size', 1, 'nswp', 10);
        results(t,1)=toc(solt0);
        results(t,2)=erank(tt_tensor(ttu));
        fprintf('TimeStep: %d (%g) done. Cum. CPU time: %g. Erank: %g\n', t, tau*t, results(t,1), results(t,2));
        if (plt==1)
            plot(x, qtt_to_full(ttu))
            str = sprintf('t: %d (%g). Erank: %g\n', t, tau*t, results(t,2));
            title(str);
            pause(0.01);
        end;
        if (plt==2)
            scatter3(x,y,qtt_to_full(ttu),5,qtt_to_full(ttu));
            colorbar;
%             view(-15,75);
            view(2);
            str = sprintf('t: %d (%g). Erank: %g\n', t, tau*t, results(t,2));
            title(str);
            pause(0.01);
        end;
    end;
else
    % Global
    results = zeros(max(size(Tsplit))-1, 2);
    
    for trange=1:max(size(Tsplit))-1
        d0t = d0ts(trange);
        last_indices = cell(d0t,1);
        for i=1:d0t
            last_indices{i}=2;
        end;
        
        tau = (Tsplit(trange+1)-Tsplit(trange))/(2^d0t);
        Grad_t = IpaS(d0t,-1);
        Grad_t = tt_matrix(Grad_t);
        Grad_t = Grad_t/tau;
        e1t = cell(d0t,1);
        for i=1:d0t
            e1t{i}=[1;0];
        end;
        e1t = tt_tensor(e1t);
        if (strcmp(scheme, 'euler'))
            Scheme_term = IpaS(d0t,0);
            Scheme_term = tt_matrix(Scheme_term);
            rhs = tt_mvk3(core(tt_Mass/tau), ttu, tol, 'verb', 0);
        else
            Scheme_term = IpaS(d0t,1);
            Scheme_term = tt_matrix(Scheme_term);
            Scheme_term = Scheme_term*0.5;
            rhs = tt_mvk3(core(tt_Mass/tau-tt_Stiff*0.5), ttu, tol, 'verb', 0);
        end;
        rhs = kron(tt_tensor(rhs), e1t);
        
        glM = kron(tt_Mass, Grad_t) + kron(tt_Stiff, Scheme_term);
        glM = round(glM, eps);
        
        solt0 = tic;
        U = dmrg_solve2(glM, rhs, tol, 'nswp', 20, 'max_full_size', 2500, 'use_self_prec', false, 'nrestart', 50);
        ttime = toc(solt0)
        results(trange, 1)=ttime;
        results(trange, 2)=erank(U);
        
        ttu = core(U);
        ttu = tt_elem3(ttu, last_indices);
        ttu = tt_squeeze(ttu);
        
        if (plt==1)
            plot(x, qtt_to_full(ttu))
            str = sprintf('trange: %d (%g). Erank: %g\n', trange, Tsplit(trange+1), results(trange,2));
            title(str);
            pause(0.01);
        end;
        if (plt==2)
            scatter3(x,y,qtt_to_full(ttu),5,qtt_to_full(ttu));
            colorbar;
%             view(-15,75);
            view(2);
            str = sprintf('t: %d (%g). Erank: %g\n', trange, Tsplit(trange+1), results(trange,2));
            title(str);
            pause(0.01);
        end;        
        pause(2);
    end;    
end;
